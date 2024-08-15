# Create a User Story and a number of Work Items and fill them with provided templates.

param(
    [Parameter(Mandatory=$true, position=0)][string]$ParentFeature,
    [Parameter(Mandatory=$true, position=1)][string]$NewUserStoryName,
    [switch]$OnlyDev,
    [switch]$OnlyTasks
)
$ErrorActionPreference = "Stop"


$organization = ""
$project = ""
$team = ""
$patToken = ""
# Set the base64 encoded PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", "$patToken")))

# Ids can be found in the template link in Settings/Team configuration/Templates.
$userStoryTemplateId = "b47c2899-e8cc-4700-b296-908d53f9c34f";
$reqTaskTemplateId = "03f3c1b4-55dd-4e3b-b1bf-d5c8b7b75f54";
$testPlanTaskTemplateId = "b1028771-6c90-49c5-a496-1d236ecbef3c";
$devTaskTemplateId = "18234889-092d-48ed-b72a-01550c19f883";
$testDevTaskTemplateId = "810eab71-2351-401a-b9f8-d4d08a42f138";

$apiLink = "https://dev.azure.com/$organization/$project/_apis/wit/workItems/"
# Define the API endpoint URL for fetching parent work item details
$uriParentWI = "$apiLink/$ParentFeature`?`$expand=all&api-version=6.0"

# Send the request to fetch parent work item details and get the response
$responseParentWI = Invoke-RestMethod -Uri $uriParentWI -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Get 

# Extract the area path from the response
$areaPath = $responseParentWI.fields.'System.AreaPath'
$stackRank = $responseParentWI.fields.'Microsoft.VSTS.Common.StackRank'
$customType = $responseParentWI.fields.'Custom.customType'

# Define the API endpoint URL for fetching the template
$uriTemplate = "https://dev.azure.com/$organization/$project/$team/_apis/wit/templates"

$userStoryUriTemplate = "$uriTemplate/$userStoryTemplateId"

# Send the request to fetch the template details and get the response
$responseTemplate = Invoke-RestMethod -Uri $userStoryUriTemplate -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Get  

# Define the API endpoint URL for creating a user story
$uriUserStory = "$apiLink/`$User%20Story?api-version=6.0"

# Define the body of the request for creating a user story
$bodyUserStory = 
	@(
		@{
			"op" = "add";
			"path" = "/fields/System.Title";
			"from" = $null;
			"value" = $NewUserStoryName;
		 },
		@{
			"op" = "add";
			"path" = "/relations/-";
			"value" = 
			@{
				"rel" = "System.LinkTypes.Hierarchy-Reverse";
				"url" = "$apiLink/$ParentFeature";
			}
		 },
		@{
			"op" = "add";
			"path" = "/fields/System.AreaPath";
			"from" = $null;
			"value" = $areaPath;
		},
        @{
			"op" = "add";
			"path" = "/fields/Custom.StoryType";
			"from" = $null;
			"value" = $customType;
		}
	)

if ($stackRank -ne $null)
{
        $bodyUserStory +=@{
			"op" = "add";
			"path" = "/fields/Microsoft.VSTS.Common.StackRank";
			"from" = $null;
			"value" = $stackRank;
		}
}

$templateFields = $responseTemplate.fields

# Add the fields from the template to the body
foreach ($field in $templateFields.psobject.properties) 
{
    $bodyUserStory += @{
        "op" = "add";
        "path" = "/fields/$($field.Name)";
        "from" = $null;
        "value" = $field.Value;
    }
}

$bodyUserStory = $bodyUserStory | ConvertTo-Json -Depth 100

if ($OnlyTasks)
{
	# Just use parent story as instead of new story.
	$newStoryId = $ParentFeature
}
else
{
	# Send the request to create a user story and get the response
	$responseUserStory = Invoke-RestMethod -Uri $uriUserStory -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Post -Body $bodyUserStory -ContentType "application/json-patch+json"
	
	# Get the ID of the newly created user story
	$newStoryId = $responseUserStory.id
}

# Define the API endpoint URL for creating a task under the new user story
$uriTask = "$apiLink/`$Task?api-version=6.1-preview.3"

# Define the prefixes for the tasks
$taskTypes = 
	@(
		@{
			Prefix = "Req"
			Template = $reqTaskTemplateId
		},
		@{
			Prefix = "Test Plan"
			Template = $testPlanTaskTemplateId
		},
		@{
			Prefix = "Dev"
			Template = $devTaskTemplateId
		},
		@{
			Prefix = "Test Dev"
			Template = $testDevTaskTemplateId
		}
	)

if ($OnlyDev)
{
	$taskTypes = @(
		@{
			Prefix = "Dev"
			Template = $devTaskTemplateId
		}
	)
}

# Define the base URL for Azure DevOps web interface
$baseUrl = "https://dev.azure.com/$organization/$project/_workitems/edit"

foreach ($taskType in $taskTypes) 
{
     # Define the body of the request for creating a task under the new user story
     $bodyTask = 
	 @(
        @{
            "op" = "add";
            "path" = "/fields/System.Title";
            "from" = $null;
            "value" = "$($taskType.Prefix): $NewUserStoryName";
        },
        @{
            "op" = "add";
            "path" = "/relations/-";
            "value" = @{
                "rel" = "System.LinkTypes.Hierarchy-Reverse";
                "url" = "$apiLink/$newStoryId";
            }
        },
		@{
			"op" = "add";
			"path" = "/fields/System.AreaPath";
			"from" = $null;
			"value" = $areaPath;
		}
     )
	
	$taskUriTemplate = "$uriTemplate/$($taskType.Template)"

	# Send the request to fetch the template details and get the response
	$responseTemplate = Invoke-RestMethod -Uri $taskUriTemplate -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Get  
	
	# Extract the fields from the template
	$templateFields = $responseTemplate.fields
	
	# Add the fields from the template to the body
	foreach ($field in $templateFields.psobject.properties) 
	{
		$bodyTask += @{
			"op" = "add";
			"path" = "/fields/$($field.Name)";
			"from" = $null;
			"value" = $field.Value;
		}
	}
	
	$bodyTask = $bodyTask | ConvertTo-Json -Depth 100
	
     # Send the request to create a task under the new user story
    $newTaskId = (Invoke-RestMethod -Uri $uriTask -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Post -Body $bodyTask -ContentType "application/json-patch+json").id
	Write-Host "$($taskType.Prefix) task was created: $baseUrl/$newTaskId"
}

# Construct the URL of the newly created work item
$newWIUrl = "$baseUrl/$newStoryId"

Write-Host "The User Story has been created at: $newWIUrl"
