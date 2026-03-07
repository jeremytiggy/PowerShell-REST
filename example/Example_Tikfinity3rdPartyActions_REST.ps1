function Get-LatestVersionedScript {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$BaseName,

        [string]$Path = "."
    )

    Write-Verbose "Searching for latest version of $BaseName in '$Path'"

    $pattern = "${BaseName}_v*.ps1"

    # Try versioned files first
    $scripts = Get-ChildItem -Path $Path -Filter $pattern -File -ErrorAction SilentlyContinue

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
    $baseFile = Join-Path $Path "${BaseName}.ps1"

    if (Test-Path $baseFile) {
        return Get-Item $baseFile
    }

    throw "No matching versioned or base script found for '$BaseName' in '$Path'."
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
                actionName  = "Gift under or 100 coins"
				applicationData = "Thank you for the Small gift"
            }

            cat1action2 = @{
                actionId    = "cat1action2"
                actionName  = "Gift over 100 coins"
				applicationData = "Thank you for the Generous gift"
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
	$Global:CV_s_TF_CategoryID = $Global:REST_API_Action_categoryId
	$Global:CV_s_TF_actionID = $Global:REST_API_Action_actionId
	$Global:CV_s_TF_userID = $Global:REST_API_clientActionData.context.userID
	$Global:CV_s_TF_username = $Global:REST_API_clientActionData.context.username
	$Global:CV_s_TF_nickname = $Global:REST_API_clientActionData.context.nickname
	$Global:CV_s_TF_profilePictureUrl = $Global:REST_API_clientActionData.context.profilePictureUrl
	$Global:CV_n_TF_coins = [int]$Global:REST_API_clientActionData.context.coins
	$Global:CV_n_TF_triggerTypeId = [int]$Global:REST_API_clientActionData.context.triggerTypeId
	$Global:CV_n_TF_tikfinityUserId = [int]$Global:REST_API_clientActionData.context.tikfinityUserId
	$Global:CV_s_TF_tikfinityUsername = $Global:REST_API_clientActionData.context.tikfinityUsername

	$Global:REST_API_Action_ApplicationDataAvailable = $true
	
	$scriptOutput = $Global:REST_API_Actions[$Global:REST_API_Action_categoryId].actions[$Global:REST_API_Action_actionId].applicationData
	$Global:CV_s_API_scriptOutput = $scriptOutput
	Write-Host "[REST_API_Application-Specific-Action] Hello, $($Global:CV_s_TF_userID) . $($Global:CV_s_API_scriptOutput)"
	
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


