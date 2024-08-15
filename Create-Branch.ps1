#Creates a branch based on the Work Item name.

param
(
	[parameter(mandatory=$true, position=0)][string]$workItemId
)
$ErrorActionPreference = "Stop"

$personalAccessToken = ""
$organization = ""
$project = ""

$script:base64AuthInfo= [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)"))
$workItem = Invoke-RestMethod -Uri "https://dev.azure.com/$organization/$project/_apis/wit/workitems/$($workItemId)?api-version=6.0" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
$branchNameBase = "feature/WI-$workItemId-$($workItem.fields.'System.Title'.Replace(" ", "-").Replace(":", "-").Replace('\', '-').Replace('"', '').Trim("."))"
$branchName = $branchNameBase
$i = 1
while (git branch -a --list $branchName) {
    $branchName = "$branchNameBase-$i"
    $i++
}
git fetch origin main:main
git checkout main
if ($LASTEXITCODE -ne 0) { throw "git checkout exit code is $LASTEXITCODE" }
git pull
git checkout -b $branchName