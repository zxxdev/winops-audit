# Loads the private helpers first, then the public cmdlets. Only the public ones are exported;
# the manifest lists them too, so PowerShell knows them before the module is imported.

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction Ignore)
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction Ignore)

foreach ($file in @($private) + @($public)) {
    . $file.FullName
}

Export-ModuleMember -Function $public.BaseName
