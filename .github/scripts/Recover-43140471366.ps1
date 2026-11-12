[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('inspect', 'delete', 'verify')]
    [string] $Mode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or
    $env:GITHUB_REPOSITORY -cne 'Azure/terraform-azurerm-avm-res-compute-virtualmachine' -or
    $env:GITHUB_EVENT_NAME -cne 'workflow_dispatch' -or
    !$env:ACTIONS_ID_TOKEN_REQUEST_URL -or !$env:ACTIONS_ID_TOKEN_REQUEST_TOKEN) {
    throw 'Recovery is restricted to this repository in GitHub Actions with CI OIDC. Local use is forbidden.'
}

$repo = 'Azure/terraform-azurerm-avm-res-compute-virtualmachine'
$runId = 43140471366
$sha = '1dacd6757508bb29cef9d20c50fab95471bb78f6'
$arm = 'https://management.azure.com'

function Get-GitHub([string] $Path, [switch] $Text) {
    $output = & gh api --hostname github.com --allow-escape-sequences $Path
    if ($LASTEXITCODE -ne 0) { throw "GitHub API failed: $Path" }
    $textOutput = $output -join "`n"
    if ($Text) { return $textOutput }
    return ($textOutput | ConvertFrom-Json -AsHashtable)
}

$run = Get-GitHub "repos/$repo/actions/runs/$runId"
if ($run.id -ne $runId -or $run.run_attempt -ne 1 -or $run.head_sha -cne $sha -or
    $run.repository.full_name -cne $repo -or $run.head_repository.full_name -cne $repo -or
    $run.path -cne '.github/workflows/pr-check.yml' -or $run.event -cne 'pull_request' -or
    $run.status -cne 'completed' -or $run.conclusion -cne 'failure' -or
    @($run.pull_requests | Where-Object { $_.number -eq 447 -and $_.head.sha -ceq $sha }).Count -ne 1) {
    throw 'Source run identity, attempt, SHA, PR or failure status does not match the pinned recovery.'
}

$sources = @(
    @{ Job = 130926099637; Name = 'Integration tests'; Group = '/subscriptions/0e4d9457-98bb-4a11-af4a-3b006c181fd7/resourceGroups/rg-vm-osdisk-upgrade-fqw777' },
    @{ Job = 131349716707; Name = 'End-to-end tests (windows_w_encryption_at_host)'; Group = '/subscriptions/a9fd0cda-2a47-4b36-b851-a5b48ce04052/resourceGroups/rg-kt0d'; Count = 15; Example = 'windows_w_encryption_at_host' },
    @{ Job = 131349716903; Name = 'End-to-end tests (windows_w_remote_access)'; Group = '/subscriptions/ddfb0a04-70b5-4059-9439-6a56d2678756/resourceGroups/rg-ekdb'; Count = 16; Example = 'windows_w_remote_access' },
    @{ Job = 131349717131; Name = 'End-to-end tests (windows_waf)'; Group = '/subscriptions/24d2cebe-faf2-4e81-9e93-04103279f302/resourceGroups/rg-zw4r'; Count = 18; Example = 'windows_waf' }
)
$manifest = @{}
foreach ($source in $sources) {
    $job = Get-GitHub "repos/$repo/actions/jobs/$($source.Job)"
    if ($job.run_id -ne $runId -or $job.run_attempt -ne 1 -or
        $job.name -cne "run managed workflow / $($source.Name)" -or $job.conclusion -cne 'failure') {
        throw "Unexpected source job identity: $($source.Job)"
    }
    $source.Start = [datetimeoffset]::Parse($job.started_at)
    $source.End = [datetimeoffset]::Parse($job.completed_at)
    $log = Get-GitHub "repos/$repo/actions/jobs/$($source.Job)/logs" -Text
    $log = $log -replace '\x1b\[[0-9;]*m', ''
    if ($source.ContainsKey('Example')) {
        $fixture = Get-GitHub "repos/$repo/contents/examples/$($source.Example)/main.tf?ref=$sha"
        $fixtureText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($fixture.content))
        if ($fixtureText -notmatch 'resource\s+"azurerm_resource_group"\s+"this_rg"') {
            throw "Source example no longer matches expected resource-group fixture: $($source.Example)"
        }
        $records = [regex]::Matches($log, '(?m)^(\d{4}-\d\d-\d\dT\S+Z)\s+(.+?): Creation complete after .+? \[id=(/subscriptions/[^\]\r\n]+)\]')
        $count = 0
        foreach ($record in $records) {
            $id = $record.Groups[3].Value
            if ($id.Contains('|') -or !$id.StartsWith("$($source.Group)/", [StringComparison]::OrdinalIgnoreCase) -and $id -ine $source.Group) {
                Write-Host "Excluded non-group or composite record: $id"
                continue
            }
            $completed = [datetimeoffset]::Parse($record.Groups[1].Value)
            if ($completed -lt $source.Start -or $completed -gt $source.End -or $manifest.ContainsKey($id)) {
                throw "Ambiguous creation record: $id"
            }
            $manifest[$id] = @{ Source = $source; Completed = $completed; Address = $record.Groups[2].Value }
            $count++
            Write-Host "PROVENANCE job=$($source.Job) completed=$completed id=$id address=$($record.Groups[2].Value)"
        }
        if ($count -ne $source.Count -or !$manifest.ContainsKey($source.Group)) {
            throw "Incomplete E2E provenance: expected $($source.Count) ARM creation records, got $count."
        }
        foreach ($line in ($log -split "`n" | Where-Object { $_ -match 'Creation complete.*(?:vault\.azure\.net|https://)' })) {
            Write-Host "DATA-PLANE PROVENANCE (not authorized for deletion): $line"
        }
    }
    else {
        $fixtures = @{}
        foreach ($path in @('tests/integration/setup/main.tf', 'tests/integration/fixtures/legacy/main.tf', 'tests/integration/os_disk_delete_option_upgrade.tftest.hcl')) {
            $file = Get-GitHub "repos/$repo/contents/${path}?ref=$sha"
            $fixtures[$path] = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($file.content))
        }
        $setup = $fixtures['tests/integration/setup/main.tf']
        $legacy = $fixtures['tests/integration/fixtures/legacy/main.tf']
        $test = $fixtures['tests/integration/os_disk_delete_option_upgrade.tftest.hcl']
        foreach ($literal in @('rg-vm-osdisk-upgrade-${random_string.suffix.result}', 'vnet-vm-osdisk-upgrade', 'disk-attached-os')) {
            if (!$setup.Contains($literal)) { throw "Source setup fixture missing $literal" }
        }
        foreach ($literal in @('${each.value.name}-${var.environment.suffix}', 'nic-${each.value.name}-${var.environment.suffix}')) {
            if (!$legacy.Contains($literal)) { throw "Source legacy fixture missing $literal" }
        }
        if (!$log.Contains("$($source.Group)/providers/Microsoft.Compute/disks/disk-attached-os") -or
            !$log.Contains('[test_cleanup]') -or !$log.Contains('"setup" -> pass')) {
            throw 'Integration logs do not establish the expected setup and cleanup failure.'
        }
        $ids = @($source.Group, "$($source.Group)/providers/Microsoft.Network/virtualNetworks/vnet-vm-osdisk-upgrade",
            "$($source.Group)/providers/Microsoft.Compute/disks/disk-attached-os")
        foreach ($name in @('vm-attach', 'vm-retain', 'vm-win')) {
            if (!$test.Contains("`"$name`"") -or !$log.Contains("`"$name-fqw777`"")) {
                throw "Integration source fixture and failure log do not agree: $name"
            }
            $ids += "$($source.Group)/providers/Microsoft.Compute/virtualMachines/$name-fqw777"
            $ids += "$($source.Group)/providers/Microsoft.Network/networkInterfaces/nic-$name-fqw777"
        }
        foreach ($id in $ids) {
            $manifest[$id] = @{ Source = $source; Completed = $source.End; Address = 'source-SHA fixture plus integration failure log' }
            Write-Host "PROVENANCE job=$($source.Job) window=$($source.Start)..$($source.End) id=$id (fixture-derived, not Creation complete)"
        }
    }
}

$tokenOutput = & az account get-access-token --resource "$arm/" --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or !$tokenOutput) { throw 'CI OIDC ARM access token is unavailable.' }
$headers = @{ Authorization = "Bearer $tokenOutput" }

function Invoke-Arm([string] $Path, [string] $Method = 'GET', [switch] $AllowMissing) {
    $uri = if ($Path.StartsWith('/')) { "$arm$Path" } else { $Path }
    if (!$uri.StartsWith("$arm/", [StringComparison]::Ordinal)) { throw "Untrusted ARM URL: $uri" }
    $response = Invoke-WebRequest -Uri $uri -Method $Method -Headers $headers -SkipHttpErrorCheck
    if ($response.StatusCode -eq 404 -and $AllowMissing) { return $null }
    if ($response.StatusCode -notin @(200, 201, 202, 204)) {
        throw "ARM $Method $uri failed: HTTP $($response.StatusCode) $($response.Content)"
    }
    if ($response.Content) { return ($response.Content | ConvertFrom-Json -AsHashtable) }
}

function Get-ArmList([string] $Path) {
    do {
        $page = Invoke-Arm $Path
        if (!$page.ContainsKey('value')) { throw "ARM list response missing value: $Path" }
        foreach ($item in $page.value) { $item }
        $Path = $page['nextLink']
    } while ($Path)
}

$versions = @{
    'Microsoft.Compute/disks' = '2024-03-02'
    'Microsoft.Compute/virtualMachines' = '2024-11-01'
    'Microsoft.Network/networkInterfaces' = '2024-05-01'
    'Microsoft.Network/publicIPAddresses' = '2024-05-01'
}
$blocked = [Collections.Generic.List[string]]::new()
$pending = [Collections.Generic.List[hashtable]]::new()
foreach ($source in $sources) {
    $group = $source.Group
    $subscription = ($group -split '/')[2]
    $locks = @(Get-ArmList "/subscriptions/$subscription/providers/Microsoft.Authorization/locks?api-version=2016-09-01")
    $scopeLocks = @($locks | Where-Object {
        $scope = $_.id -replace '/providers/Microsoft.Authorization/locks/[^/]+$', ''
        $scope -ieq "/subscriptions/$subscription" -or $scope -ieq $group -or
        $scope.StartsWith("$group/", [StringComparison]::OrdinalIgnoreCase)
    })
    if ($scopeLocks.Count) {
        $blocked.Add("Locks prohibit recovery in $group : $($scopeLocks.id -join ', ')")
    }
    $currentGroup = Invoke-Arm "${group}?api-version=2024-11-01" -AllowMissing
    if (!$currentGroup) {
        Write-Host "ABSENT group=$group"
        continue
    }
    $live = @(Get-ArmList "${group}/resources?api-version=2021-04-01&`$expand=createdTime")
    Write-Host "RETAIN group=$group (resource-group deletion is never authorized)"
    foreach ($resource in $live) {
        $id = $resource.id
        Write-Host "CURRENT $($resource | ConvertTo-Json -Depth 30 -Compress)"
        if ($Mode -eq 'verify') {
            $blocked.Add("Resource remains: $id")
            continue
        }
        $reason = $null
        if (!$manifest.ContainsKey($id)) { $reason = 'not in source provenance manifest' }
        elseif (!$versions.ContainsKey($resource.type)) { $reason = 'container/child-resource deletion is not authorized by this recovery' }
        elseif ($scopeLocks.Count) { $reason = 'scope is locked' }
        else {
            $proof = $manifest[$id]
            $created = $resource['createdTime']
            if (!$created -or [datetimeoffset]::Parse($created) -lt $proof.Source.Start -or
                [datetimeoffset]::Parse($created) -gt $proof.Completed) {
                $reason = 'missing creation metadata or creation outside source job/record window'
            }
        }
        if ($reason) {
            Write-Host "REFUSE id=$id reason=$reason"
            $blocked.Add("$id : $reason")
            continue
        }
        $path = "${id}?api-version=$($versions[$resource.type])"
        $detail = Invoke-Arm $path
        if ($detail.id -ine $id -or !$detail['etag']) {
            Write-Host "REFUSE id=$id reason=exact identity/ETag unavailable"
            $blocked.Add("$id : exact identity/ETag unavailable")
            continue
        }
        $dependencies = @()
        if ($resource.type -ieq 'Microsoft.Compute/virtualMachines') {
            $dependencies = @($detail.properties.storageProfile.osDisk.managedDisk.id)
            $dependencies += @($detail.properties.storageProfile['dataDisks'] | ForEach-Object { $_.managedDisk.id })
            $dependencies += @($detail.properties.networkProfile.networkInterfaces | ForEach-Object { $_.id })
            if (@($dependencies | Where-Object { !$_ -or !$manifest.ContainsKey($_) }).Count) {
                $blocked.Add("$id : VM references resources outside the proven manifest")
                continue
            }
            $extensions = @(Get-ArmList "${id}/extensions?api-version=2024-11-01")
            if ($extensions.Count) {
                $blocked.Add("$id : VM extension deletion is not authorized")
                continue
            }
        }
        Write-Host "ALLOW id=$id created=$created source-job=$($manifest[$id].Source.Job)"
        $pending.Add(@{ Id = $id; Path = $path; Etag = $detail.etag; Group = $group; Subscription = $subscription; Type = $resource.type; Dependencies = $dependencies })
    }
}

if ($Mode -eq 'delete') {
    foreach ($item in ($pending | Sort-Object { if ($_.Type -ieq 'Microsoft.Compute/virtualMachines') { 0 } else { 1 } })) {
        foreach ($dependency in $item.Dependencies) {
            $approved = @($pending | Where-Object { $_.Id -ieq $dependency })
            if ($approved.Count -ne 1) { throw "VM dependency lacks independently verified current ownership: $dependency" }
            $dependencyNow = Invoke-Arm $approved[0].Path
            if ($dependencyNow.id -ine $dependency -or $dependencyNow.etag -cne $approved[0].Etag) {
                throw "VM dependency changed after ownership inspection: $dependency"
            }
        }
        $locks = @(Get-ArmList "/subscriptions/$($item.Subscription)/providers/Microsoft.Authorization/locks?api-version=2016-09-01")
        if ($locks.Count) { throw 'A subscription lock exists; refusing deletion on final lock check.' }
        $fresh = Invoke-Arm $item.Path
        if ($fresh.id -ine $item.Id -or $fresh.etag -cne $item.Etag) {
            throw "Resource changed after ownership inspection: $($item.Id)"
        }
        if ($item.Type -ieq 'Microsoft.Compute/virtualMachines' -and
            @(Get-ArmList "$($item.Id)/extensions?api-version=2024-11-01").Count) {
            throw "VM extensions appeared after ownership inspection: $($item.Id)"
        }
        $headers['If-Match'] = $item.Etag
        $null = Invoke-Arm $item.Path -Method DELETE
        $headers.Remove('If-Match')
        $removed = $false
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            $remaining = Invoke-Arm $item.Path -AllowMissing
            $listed = @(Get-ArmList "$($item.Group)/resources?api-version=2021-04-01" | Where-Object { $_.id -ieq $item.Id })
            if (!$remaining -and !$listed.Count) { $removed = $true; break }
            Start-Sleep -Seconds 10
        }
        if (!$removed) { throw "Fresh GET/list still finds deleted resource: $($item.Id)" }
        Write-Host "VERIFIED REMOVED $($item.Id)"
    }
}
foreach ($message in $blocked) { Write-Host "UNRESOLVED $message" }
if ($Mode -ne 'inspect' -and $blocked.Count) {
    throw "Recovery incomplete: $($blocked.Count) unresolved resources/scopes. No container, data-plane object, subscription feature or unproven resource is authorized for deletion."
}
