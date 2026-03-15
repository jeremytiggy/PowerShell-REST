function Get-LatestVersionedScript {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$BaseName,

        [string[]]$Path = @(".", ".\lib")
    )

    foreach ($currentPath in $Path) {

        Write-Verbose "Searching for latest version of $BaseName in '$currentPath'"

        $pattern = "${BaseName}_v*.ps1"

        # Try versioned files first
        $scripts = Get-ChildItem -Path $currentPath -Filter $pattern -File -ErrorAction SilentlyContinue

        if ($scripts) {

            $latest = $scripts |
                Sort-Object {
                    if ($_.Name -match 'v(\d+(\.\d+)+)') {
                        [version]$matches[1]
                    }
                    else {
                        [version]"0.0"
                    }
                } -Descending |
                Select-Object -First 1

            return $latest
        }

        # Fallback to non-versioned file
        $baseFile = Join-Path $currentPath "${BaseName}.ps1"

        if (Test-Path $baseFile) {
            return Get-Item $baseFile
        }
    }

    throw "No matching versioned or base script found for '$BaseName' in paths: $($Path -join ', ')"
}

# Include library REST Server
# Include REST_API_Server.ps1 pipe communication functions and variables
try {

    $script = Get-LatestVersionedScript -BaseName "REST_API_Server"

    Write-Host "Loading $($script.Name)..."

    . $script.FullName

}
catch {

    Write-Host "Failed to load latest REST_API_Server."
    Write-Host $_
    exit 1

}
REST_API_SERVER_LibraryLoaded

# Pasting header from library
# USER AND APPLICATION SPECIFIC DATA ------------------------------
# Copy this section into your script to overwrite these values with application specific values
# Windows HTTP REST Server Setup --------------------------------
# HTTP Parameters (Required)
$Global:REST_Server_Port = 8832
$Global:REST_Server_Uri = "http://127.0.0.1:$Global:REST_Server_Port/"
# Partner Process Name (Optional)
$Global:REST_Client_processName = "Tikfinity"
# REST API Application Information (Required)
$Global:REST_API_appInfo = 	@{
						author = "John Doe"
						name = "Tikfinity Event REST API" 
						version = "1.0"
					}
Write-Host "[REST_API_Server] Parameters registered. May be overwritten." -ForegroundColor Yellow
# REST API Data Definitions for Actions (Required)
# Define action categories and their corresponding actions for the REST API
# Each action category has a unique identifier (categoryId) and a human-readable name (categoryName).
# Each action within a category has a unique identifier (actionId) and a human-readable name (actionName).
# Replace with your own definitions

$Global:REST_API_Actions = @{
    cat1 = @{
        categoryId   = "cat1"
        categoryName = "Gift"

        actions = @{
            cat1action1 = @{
                actionId    = "cat1action1"
                actionName  = "Gift with Coins"
				applicationData = "Thank you for the gift of {{context.coins}} coins, {{context.nickname}}!"
            }

            cat1action2 = @{
                actionId    = "cat1action2"
                actionName  = "Gift over 100 coins"
				applicationData = "OMG! @{{context.username}}! {{context.coins}} is too much!"
            }
        }
    }

    cat2 = @{
        categoryId   = "cat2"
        categoryName = "Command"

        actions = @{
            cat2action1 = @{
                actionId    = "cat2action1"
                actionName  = "!smile"
				applicationData = ":-)"
            }

            cat2action2 = @{
                actionId    = "cat2action2"
                actionName  = "!frown"
                applicationData = ":-("
            }
        }
    }
}
$Global:REST_API_Tikfinity_JSON_ExecuteThirdPartyAction = @'
{
  "categoryId": "categoryId",
  "actionId": "actionId",
  "context": {
    "userID": "userID",
    "username": "username",
    "nickname": "nickname",
    "profilePictureUrl": "https://about:blank",
    "coins": 999,
    "triggerTypeId": -1,
    "tikfinityUserId": 123456789,
    "tikfinityUsername": "tikfinityUsername"
  }
}
'@

Write-Host "[REST_API_Server] Action Categories & Definitions registered. May be overwritten." -ForegroundColor Yellow
# REST API Data Definitions for Actions ^^^^^^^^^^^^^^^^
# Function to Run on REST Action (Required)
# Put your code that performs your desired activity for this plug-in
function REST_API_Application-Specific-Action {
	#Overwrite this function with your own function to execute when a valid REST action is received
	#Print a thank you message to the user 
	#Tikfinity has a known Events JSON
	$tikfinity_ExecuteAction = $Global:REST_API_clientActionData
	if ($Global:REST_API_Debug) { 
		Write-Host "[REST_API_Application-Specific-Action]: DEBUG - printing tikfinity_ExecuteAction" -ForegroundColor Gray 
		Show-ObjectProperties -Obj $tikfinity_ExecuteAction
	}
	$Global:CV_s_TF_CategoryID = $tikfinity_ExecuteAction.categoryId
	$Global:CV_s_TF_actionID = $tikfinity_ExecuteAction.actionId

	$Global:CV_s_TF_username = $tikfinity_ExecuteAction.context.username
	$Global:CV_s_TF_nickname = $tikfinity_ExecuteAction.context.nickname
	$Global:CV_n_TF_coins = [int]$tikfinity_ExecuteAction.context.coins
	#$Global:CV_n_TF_triggerTypeId = [int]$Global:REST_API_clientActionData.context.triggerTypeId
	$Global:CV_n_TF_triggerTypeId = Get-MemberValueFromUnknownObject -objectWithUnknownMembers $tikfinity_ExecuteAction -targetMember_nameString "context.triggerTypeId"
	<#
	triggerTypeId detail
	1 = Share
	2 = Command
	3 = Gift (min coins value)
	4 = Gift (specific gift)
	6 = Join
	7 = Likes (taps)
	9 = Follow
	10 = Subscribe
	11 = Chat (any message)
	12 = Emote
	13 = First User Activity
	#>

	$Global:REST_API_Action_ApplicationDataAvailable = $true
	
	$screenMessageWithPlaceholders = $Global:REST_API_Action.applicationData
	if ($Global:REST_API_Debug) { Write-Host "[REST_API_Application-Specific-Action]: DEBUG - screen message with placeholders: $($screenMessageWithPlaceholders)" -ForegroundColor Gray }
	$screenMessage = Replace-PlaceholdersWithValues -stringContainingPlaceholders $screenMessageWithPlaceholders -objectWithValues $tikfinity_ExecuteAction
	Write-Host "[REST_API_Application-Specific-Action] $($screenMessage)"
}
Write-Host "[REST_API_Server] REST_API_Application-Specific-Action registered. May be overwritten." -ForegroundColor Yellow
# Windows HTTP REST Server Setup ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# Important Global Parameters
$Global:REST_Server_Running = $false 		# Server Status
$Global:REST_Server_Listener = $null				# HTTP Handler Object
$Global:REST_Server_Debug = $false
$Global:REST_API_clientActionData = $null				# Client Data received during Event Action
$Global:REST_API_Action_categoryId = ""
$Global:REST_API_Action_actionId = ""
$Global:REST_API_Action = $null
$Global:REST_API_Action_Category = $null
$Global:REST_API_Action_ApplicationDataAvailable = $false
$Global:REST_API_Action_Executed = $false
$Global:REST_API_Debug = $false
# USER AND APPLICATION SPECIFIC DATA ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

function Edit-ObjectInteractive {
    param(
        [Parameter(Mandatory)]
        [psobject]$Object,

        [string]$Path = ""
    )

    $fnName = $MyInvocation.MyCommand.Name
    foreach ($prop in $Object.PSObject.Properties) {

        $currentPath = if ($Path) {
            "$Path.$($prop.Name)"
        } else {
            $prop.Name
        }

        $value = $prop.Value

        # Nested PSCustomObject - Recurse
        if ($value -is [PSCustomObject]) {
            Edit-ObjectInteractive -Object $value -Path $currentPath
        }

        # Array - Iterate
        elseif ($value -is [System.Collections.IEnumerable] -and
                -not ($value -is [string])) {

            for ($i = 0; $i -lt $value.Count; $i++) {

                $itemPath = "$currentPath[$i]"
                $item = $value[$i]

                if ($item -is [PSCustomObject]) {
                    Edit-ObjectInteractive -Object $item -Path $itemPath
                }
                else {
                    Show-EditPrompt -FunctionName $fnName -Path $itemPath -Value $item
                    $newValue = Read-Host "  Enter new value (blank = keep)"

                    if ($newValue -ne "") {
                        $value[$i] = Convert-ToOriginalType $newValue $item
                    }
                }
            }
        }

        # Leaf Property - Prompt
        else {
            Show-EditPrompt -FunctionName $fnName -Path $currentPath -Value $value
            $newValue = Read-Host "  Enter new value (blank = keep)"

            if ($newValue -ne "") {
                $Object.$($prop.Name) = Convert-ToOriginalType $newValue $value
            }
        }
    }
}

function Show-EditPrompt {
    param(
        [string]$FunctionName,
        [string]$Path,
        $Value
    )

    $typeName = if ($null -ne $Value) { $Value.GetType().Name } else { "null" }

    Write-Host ""
    Write-Host "[$FunctionName] $Path" -ForegroundColor Cyan
    Write-Host "  Current : $Value ($typeName)" -ForegroundColor Gray
}

function Convert-ToOriginalType {
    param(
        [string]$InputValue,
        $OriginalValue
    )

    if ($null -eq $OriginalValue) {
        return $InputValue
    }

    $type = $OriginalValue.GetType()

    try {
        switch ($type.Name) {
            "Int32"    { return [int]$InputValue }
            "Int64"    { return [long]$InputValue }
            "Double"   { return [double]$InputValue }
            "Decimal"  { return [decimal]$InputValue }
            "Boolean"  { return [bool]$InputValue }
            "DateTime" { return [datetime]$InputValue }
            "String"   { return [string]$InputValue }
            default    { return [System.Convert]::ChangeType($InputValue, $type) }
        }
    }
    catch {
        Write-Warning "Could not convert '$InputValue' to [$($type.Name)]. Keeping original value."
        return $OriginalValue
    }
}

# Main Program Loop -------------------------------
# ask if user wants to enable debugging
if ($Global:REST_Server_Debug -eq $false) {
	Write-Host "'n[Startup]: Enable Server Debugging Messages?" -ForegroundColor Cyan
	Write-Host -NoNewLine "[Enter Command (yes|no)]:> "
	$enableServerDebugging = Read-Host
	if ($enableServerDebugging -eq 'yes') { $Global:REST_Server_Debug = $true }
}
if ($Global:REST_API_Debug -eq $false) {
	Write-Host "[Startup]: Enable REST API Debugging Messages?" -ForegroundColor Cyan
	Write-Host -NoNewLine "[Enter Command (yes|no)]:> "
	$enable_REST_API_Debugging = Read-Host
	if ($enable_REST_API_Debugging -eq 'yes') { $Global:REST_API_Debug = $true }
}

Write-Host "[Startup]: Starting communications..." -ForegroundColor White
$Global:REST_Server_Running = $false
REST_Server_Startup

# Communication Status After Startups
if ($Global:REST_Server_Running) {
    Write-Host "[Startup]: HTTP REST Response Server is running." -ForegroundColor Green
} else {
    Write-Host "[Startup]: HTTP REST Response Server is not running." -ForegroundColor Yellow
}



Write-Host "`n[Startup]: Starting main loop..." -ForegroundColor White
try {
    while ($true) {
        Write-Host "[Main Loop]: Listening for REST Server requests..." -ForegroundColor White
		REST_Server_Wait-For-Request
		if ($Global:REST_Server_Running -ne $true) {
            Write-Host "[Offline]: Once you 'start' the REST server, you lose all manual functionality." -ForegroundColor Yellow
            Write-Host -NoNewline "[Offline]: Enter Command (exit|start|simulate)> "
            $cmd = Read-Host
            if ($cmd -ne '') {
			    if ($cmd -eq 'exit') { break }
                elseif ($cmd -eq 'start') { REST_Server_Startup }
                elseif ($cmd -eq 'simulate') {
                    Write-Host "[Simulate]: Incoming Third Party Action Data" -ForegroundColor Yellow
					$Global:REST_API_clientActionData = $Global:REST_API_Tikfinity_JSON_ExecuteThirdPartyAction | ConvertFrom-Json
					Edit-ObjectInteractive -Object $Global:REST_API_clientActionData
					REST_API_Process-clientActionData
                }
			    else { Write-Host '[Invalid Command]' }
		    } # end cmd selection
        } #end server not running
		
        
		#APPLICATION SPECIFIC LOGIC
        # If request is an action execution, acknowledge
        if ($Global:REST_API_Action_Executed) {
			$Global:REST_API_Action_Executed = $false
        }
		# END OF APPLICATION SPECIFIC LOGIC

    } # end of main while loop

} catch {
    Write-Host "SERVER ERROR: $($_.Exception.Message)" -ForegroundColor Red
} finally {
	Write-Host "=== CLIENT SHUTDOWN ===" -ForegroundColor Cyan
}


