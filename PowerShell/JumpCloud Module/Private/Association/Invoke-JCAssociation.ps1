﻿Function Invoke-JCAssociation
{
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)][ValidateNotNullOrEmpty()][ValidateSet('add', 'get', 'remove')][string]$Action,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1, HelpMessage = 'The type of the object.')][ValidateNotNullOrEmpty()][ValidateSet('command', 'ldap_server', 'policy', 'application', 'radius_server', 'system_group', 'system', 'user_group', 'user', 'g_suite', 'office_365')][Alias('TypeNameSingular')][string]$Type
        , [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 2, HelpMessage = 'Bypass user confirmation and ValidateSet when adding or removing associations.')][ValidateNotNullOrEmpty()][Switch]$Force
    )
    DynamicParam
    {
        # Build dynamic parameters
        $RuntimeParameterDictionary = Get-DynamicParamAssociation @PsBoundParameters
        Return $RuntimeParameterDictionary
    }
    Begin
    {
        # Debug message for parameter call
        Invoke-Command -ScriptBlock:($ScriptBlock_DefaultDebugMessageBegin) -ArgumentList:($MyInvocation, $PsBoundParameters, $PSCmdlet) -NoNewScope
        $Results = @()
    }
    Process
    {
        # For DynamicParam with a default value set that value and then convert the DynamicParam inputs into new variables for the script to use
        Invoke-Command -ScriptBlock:($ScriptBlock_DefaultDynamicParamProcess) -ArgumentList:($PsBoundParameters, $PSCmdlet, $RuntimeParameterDictionary) -NoNewScope
        Try
        {
            # All the bindings, recursive , both direct and indirect
            $URL_Template_Associations_MemberOf = '/api/v2/{0}/{1}/memberof' # $SourcePlural, $SourceId
            $URL_Template_Associations_Membership = '/api/v2/{0}/{1}/membership' # $SourcePlural (systemgroups,usergroups), $SourceId
            $URL_Template_Associations_TargetType = '/api/v2/{0}/{1}/{2}' # $SourcePlural, $SourceId, $TargetPlural
            # Only direct bindings and don’t traverse through groups
            $URL_Template_Associations_Targets = '/api/v2/{0}/{1}/associations?targets={2}' # $SourcePlural, $SourceId, $TargetSingular
            $URL_Template_Associations_Members = '/api/v2/{0}/{1}/members' # $SourcePlural, $SourceId
            # ScriptBlock used for building get associations results
            Function Format-JCAssociation
            {
                Param (
                    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)][ValidateNotNullOrEmpty()][string]$Uri
                    , [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)][ValidateNotNullOrEmpty()][string]$Method
                    , [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 2)][ValidateNotNullOrEmpty()][object]$Source
                    , [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 3)][ValidateNotNullOrEmpty()][object]$Target
                    , [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 4)][ValidateNotNullOrEmpty()][bool]$IncludeInfo = $false
                    , [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 5)][ValidateNotNullOrEmpty()][bool]$IncludeNames = $false
                    , [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 6)][ValidateNotNullOrEmpty()][bool]$IncludeVisualPath = $false
                    , [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 7)][ValidateNotNullOrEmpty()][bool]$Raw = $false
                )
                Write-Debug ('[UrlTemplate]:' + $Uri)
                $AssociationsOut = @()
                $Associations = Invoke-JCApi -Method:($Method) -Paginate:($true) -Url:($Uri)
                If ($Associations -and $Associations.PSObject.Properties.name -notcontains 'NoContent')
                {
                    ForEach ($Association In $Associations)
                    {
                        # For source determine if association is direct or indirect
                        $associationType = If (($Association | ForEach-Object {($_.paths.to | Measure-Object).Count}) -eq 1 -or ($Association | ForEach-Object {($_.paths.to | Measure-Object).Count}) -eq 0) {'direct'}
                        ElseIf (($Association | ForEach-Object {($_.paths.to | Measure-Object).Count}) -gt 1) {'indirect'}
                        Else {'unknown;The count of paths is:' + ($_.paths.to | Measure-Object).Count}
                        # Raw switch allows for the user to return an unformatted version of what the api endpoint returns
                        If ($Raw)
                        {
                            Add-Member -InputObject:($Association) -NotePropertyName:('associationType') -NotePropertyValue:($associationType);
                            $AssociationsOut += $Association
                        }
                        Else
                        {
                            $AssociationHash = [ordered]@{
                                'associationType'  = $associationType;
                                'id'               = $Source.($Source.ById);
                                'type'             = $Source.TypeNameSingular;
                                'name'             = $null;
                                'info'             = $null;
                                'targetId'         = $null;
                                'targetType'       = $null;
                                'targetName'       = $null;
                                'targetInfo'       = $null;
                                'visualPathById'   = $null;
                                'visualPathByName' = $null;
                                'visualPathByType' = $null;
                            };
                            # Dynamically get the rest of the properties and add them to the object
                            $Association |
                                ForEach-Object {$_.PSObject.Properties.name} |
                                Select-Object -Unique |
                                Where-Object {$_ -notin ('id', 'type')} |
                                ForEach-Object {$AssociationHash.Add($_, $Association.($_)) | Out-Null}
                            # If a $Target is not passed in and any "Include*" switch is provided get the target object
                            If (-not $Target -and $IncludeInfo -or $IncludeNames -or $IncludeVisualPath)
                            {
                                $Target = Get-JCObject -Type:($Association.type) -Id:($Association.id)
                            }
                            # If target is populated
                            If ($Target)
                            {
                                $AssociationHash.targetId = $Target.($Target.ById)
                                $AssociationHash.targetType = $Target.TypeNameSingular
                            }
                            Else
                            {
                                $AssociationHash.targetId = $Association.id
                                $AssociationHash.targetType = $Association.type
                            }
                            # Show source and target info
                            If ($IncludeInfo)
                            {
                                $AssociationHash.info = $Source
                                $AssociationHash.targetInfo = $Target
                            }
                            # Show names of source and target
                            If ($IncludeNames)
                            {
                                $AssociationHash.name = $Source.($Source.ByName)
                                $AssociationHash.targetName = $Target.($Target.ByName)
                            }
                            # Map out the associations path and show
                            If ($IncludeVisualPath)
                            {
                                class AssociationMap
                                {
                                    [string]$Id; [string]$Name; [string]$Type;
                                    AssociationMap([string]$i, [string]$n, [string]$t) {$this.Id = $i; $this.Name = $n; $this.Type = $t; }
                                }
                                $Association.paths | ForEach-Object {
                                    $AssociationVisualPath = @()
                                    [AssociationMap]$AssociationVisualPathRecord = [AssociationMap]::new($Source.($Source.ById), $Source.($Source.ByName), $Source.TypeNameSingular)
                                    $AssociationVisualPath += $AssociationVisualPathRecord
                                    $_.to | ForEach-Object {
                                        $AssociationPathToItemInfo = Get-JCObject -Type:($_.type) -Id:($_.id)
                                        $AssociationVisualPath += [AssociationMap]::new($_.id, $AssociationPathToItemInfo.($AssociationPathToItemInfo.ByName), $_.type)
                                    }
                                    ($AssociationVisualPath | ForEach-Object {$_.PSObject.Properties.name} |
                                            Select-Object -Unique) |
                                        ForEach-Object {
                                        $KeyName_visualPath = 'visualPathBy' + $_
                                        $AssociationHash.($KeyName_visualPath) = ('"' + ($AssociationVisualPath.($_) -join '" -> "') + '"')
                                    }
                                }
                            }
                            # Convert the hashtable to an object where the Value has been populated
                            $AssociationsUpdated = [PSCustomObject]@{}
                            $AssociationHash.GetEnumerator() |
                                ForEach-Object {If ($_.Value) {Add-Member -InputObject:($AssociationsUpdated) -NotePropertyName:($_.Key) -NotePropertyValue:($_.Value)}}
                            $AssociationsOut += $AssociationsUpdated
                        }
                    }
                    Return $AssociationsOut
                }
            }
            # Determine to search by id or name but always prefer id
            If ($Id)
            {
                $SourceItemSearchByValue = $Id
                $SourceSearchBy = 'ById'
            }
            ElseIf ($Name)
            {
                $SourceItemSearchByValue = $Name
                $SourceSearchBy = 'ByName'
            }
            Else
            {
                Write-Error ('-Id or -Name parameter must be populated.') -ErrorAction:('Stop')
            }
            # Get SourceInfo
            $Source = Get-JCObject -Type:($Type) -SearchBy:($SourceSearchBy) -SearchByValue:($SourceItemSearchByValue)
            If ($Source)
            {
                ForEach ($SourceItem In $Source)
                {
                    $SourceItemId = $SourceItem.($SourceItem.ById)
                    $SourceItemName = $SourceItem.($SourceItem.ByName)
                    $SourceItemTypeName = $SourceItem.TypeName
                    $SourceItemTypeNameSingular = $SourceItemTypeName.TypeNameSingular
                    $SourceItemTypeNamePlural = $SourceItemTypeName.TypeNamePlural
                    $SourceItemTargets = $SourceItem.Targets |
                        Where-Object { $_.TargetSingular -in $TargetType -or $_.TargetPlural -in $TargetType }
                    ForEach ($SourceItemTarget In $SourceItemTargets)
                    {
                        $SourceItemTargetSingular = $SourceItemTarget.TargetSingular
                        $SourceItemTargetPlural = $SourceItemTarget.TargetPlural
                        # Build Url based upon source and target combinations
                        If (($SourceItemTypeNamePlural -eq 'systems' -and $SourceItemTargetPlural -eq 'systemgroups') -or ($SourceItemTypeNamePlural -eq 'users' -and $SourceItemTargetPlural -eq 'usergroups'))
                        {
                            $Uri_Associations_GET = $URL_Template_Associations_MemberOf -f $SourceItemTypeNamePlural, $SourceItemId
                        }
                        ElseIf (($SourceItemTypeNamePlural -eq 'systemgroups' -and $SourceItemTargetPlural -eq 'systems') -or ($SourceItemTypeNamePlural -eq 'usergroups' -and $SourceItemTargetPlural -eq 'users'))
                        {
                            $Uri_Associations_GET = $URL_Template_Associations_Membership -f $SourceItemTypeNamePlural, $SourceItemId
                        }
                        ElseIf (($SourceItemTypeNamePlural -eq 'activedirectories' -and $SourceItemTargetPlural -eq 'users') -or ($SourceItemTypeNamePlural -eq 'users' -and $SourceItemTargetPlural -eq 'activedirectories'))
                        {
                            $Uri_Associations_GET = $URL_Template_Associations_Targets -f $SourceItemTypeNamePlural, $SourceItemId, $SourceItemTargetSingular
                        }
                        Else
                        {
                            $Uri_Associations_GET = $URL_Template_Associations_TargetType -f $SourceItemTypeNamePlural, $SourceItemId, $SourceItemTargetPlural
                        }
                        # Call endpoint
                        If ($Action -eq 'get')
                        {
                            $AssociationOut = @()
                            # If switches are not passed in set them to be false so they can be used with Format-JCAssociation
                            If (!($IncludeInfo)) {$IncludeInfo = $false; }
                            If (!($IncludeNames)) {$IncludeNames = $false; }
                            If (!($IncludeVisualPath)) {$IncludeVisualPath = $false; }
                            If (!($Raw)) {$Raw = $false; }
                            # Get associations and format the output
                            $Association = Format-JCAssociation -Uri:($Uri_Associations_GET) -Method:('GET') -Source:($SourceItem) -IncludeInfo:($IncludeInfo) -IncludeNames:($IncludeNames) -IncludeVisualPath:($IncludeVisualPath) -Raw:($Raw)
                            If ($Direct -eq $true)
                            {
                                $AssociationOut += $Association | Where-Object {$_.associationType -eq 'direct'}
                            }
                            If ($Indirect -eq $true)
                            {
                                $AssociationOut += $Association | Where-Object {$_.associationType -eq 'indirect'}
                            }
                            If (!($Direct) -and !($Indirect))
                            {
                                $AssociationOut += $Association
                            }
                            If ($Raw)
                            {
                                $Result = $AssociationOut | Select-Object -Property:('*') -ExcludeProperty:('associationType')
                                $Results += $Result
                            }
                            Else
                            {
                                $Result = $AssociationOut
                                $Results += $Result
                            }
                        }
                        Else
                        {
                            # For target determine to search by id or name but always prefer id
                            If ($TargetId -and $TargetName)
                            {
                                Write-Error ('Both the -TargetId and -TargetName have been provided. Function only accepts -TargetId or -TargetName.') -ErrorAction:('Stop')
                            }
                            ElseIf ($TargetId)
                            {
                                $TargetSearchByValue = $TargetId
                                $TargetSearchBy = 'ById'
                            }
                            ElseIf ($TargetName)
                            {
                                $TargetSearchByValue = $TargetName
                                $TargetSearchBy = 'ByName'
                            }
                            Else
                            {
                                Write-Error ('-TargetId or -TargetName parameter must be populated.') -ErrorAction:('Stop')
                            }
                            # Get Target object
                            $Target = Get-JCObject -Type:($SourceItemTargetSingular) -SearchBy:($TargetSearchBy) -SearchByValue:($TargetSearchByValue)
                            If ($Target)
                            {
                                ForEach ($TargetItem In $Target)
                                {
                                    $TargetItemId = $TargetItem.($TargetItem.ById)
                                    $TargetItemName = $TargetItem.($TargetItem.ByName)
                                    $TargetItemTypeNameSingular = $TargetItem.TypeName.TypeNameSingular
                                    $TargetItemTypeNamePlural = $TargetItem.TypeName.TypeNamePlural
                                    # Build the attributes for the json body string
                                    $AttributesValue = If ($Action -eq 'add' -and $Attributes)
                                    {
                                        $Attributes | ConvertTo-Json -Depth:(100) -Compress
                                    }
                                    Else
                                    {
                                        'null'
                                    }
                                    # Validate that the association exists
                                    $TestAssociation = Format-JCAssociation -Uri:($Uri_Associations_GET) -Method:('GET') -Source:($SourceItem) -Target:($TargetItem) -IncludeNames:($true)
                                    Where-Object {$_.TargetId -eq $TargetItemId}
                                    $IndirectAssociations = $TestAssociation  | Where-Object {$_.associationType -ne 'direct'}
                                    $Result = $TestAssociation  | Where-Object {$_.associationType -eq 'direct'}
                                    If ($TargetItemId -ne $IndirectAssociations.targetId)
                                    {
                                        # Build uri and body
                                        If (($SourceItemTypeNamePlural -eq 'systems' -and $SourceItemTargetPlural -eq 'systemgroups') -or ($SourceItemTypeNamePlural -eq 'users' -and $SourceItemTargetPlural -eq 'usergroups'))
                                        {
                                            $Uri_Associations_POST = $URL_Template_Associations_Members -f $TargetItemTypeNamePlural, $TargetItemId
                                            $JsonBody = '{"op":"' + $Action + '","type":"' + $SourceItemTypeNameSingular + '","id":"' + $SourceItemId + '","attributes":' + $AttributesValue + '}'
                                        }
                                        ElseIf (($SourceItemTypeNamePlural -eq 'systemgroups' -and $SourceItemTargetPlural -eq 'systems') -or ($SourceItemTypeNamePlural -eq 'usergroups' -and $SourceItemTargetPlural -eq 'users'))
                                        {
                                            $Uri_Associations_POST = $URL_Template_Associations_Members -f $SourceItemTypeNamePlural, $SourceItemId
                                            $JsonBody = '{"op":"' + $Action + '","type":"' + $TargetItemTypeNameSingular + '","id":"' + $TargetItemId + '","attributes":' + $AttributesValue + '}'
                                        }
                                        Else
                                        {
                                            $Uri_Associations_POST = $URL_Template_Associations_Targets -f $SourceItemTypeNamePlural, $SourceItemId, $SourceItemTargetSingular
                                            $JsonBody = '{"op":"' + $Action + '","type":"' + $TargetItemTypeNameSingular + '","id":"' + $TargetItemId + '","attributes":' + $AttributesValue + '}'
                                        }
                                        # Send body to endpoint.
                                        Write-Verbose ('"' + $Action + '" the association between the "' + $SourceItemTypeNameSingular + '" "' + $SourceItemName + '" and the "' + $TargetItemTypeNameSingular + '" "' + $TargetItemName + '"')
                                        Write-Debug ('[UrlTemplate]:' + $Uri_Associations_POST + '; Body:' + $JsonBody + ';')
                                        If (!($Force))
                                        {
                                            Do
                                            {
                                                $HostResponse = Read-Host -Prompt:('Are you sure you want to "' + $Action + '" the association between the "' + $SourceItemTypeNameSingular + '" called "' + $SourceItemName + '" and the "' + $TargetItemTypeNameSingular + '" called "' + $TargetItemName + '"?[Y/N]')
                                            }
                                            Until ($HostResponse -in ('y', 'n'))
                                        }
                                        If ($HostResponse -eq 'y' -or $Force)
                                        {
                                            Try
                                            {
                                                $JCApi = Invoke-JCApi -Body:($JsonBody) -Method:('POST') -Url:($Uri_Associations_POST)
                                                $ActionResult = $JCApi | Select-Object * `
                                                    , @{Name = 'IsSuccessStatusCode'; Expression = {$JCApi.httpMetaData.BaseResponse.IsSuccessStatusCode}} `
                                                    , @{Name = 'error'; Expression = {$null}}
                                            }
                                            Catch
                                            {
                                                $ActionResult = [PSCustomObject]@{
                                                    'IsSuccessStatusCode' = $_.Exception.Response.IsSuccessStatusCode;
                                                    'error'               = $_;
                                                }
                                                Write-Error ($_)
                                            }
                                        }
                                    }
                                    # Get the newly created association
                                    If ($Action -eq 'add')
                                    {
                                        $Result = Format-JCAssociation -Uri:($Uri_Associations_GET) -Method:('GET') -Source:($SourceItem) -Target:($TargetItem) -IncludeNames:($true)
                                        Where-Object {$_.TargetId -eq $TargetItemId}
                                    }
                                    # Append record status
                                    $Results += If ($Result)
                                    {
                                        $Result | Select-Object * `
                                            , @{Name = 'action'; Expression = {$Action}} `
                                            , @{Name = 'IsSuccessStatusCode'; Expression = {$ActionResult.IsSuccessStatusCode}} `
                                            , @{Name = 'error'; Expression = {$ActionResult.error}}
                                    }
                                }
                            }
                            Else
                            {
                                Write-Error ('Unable to find the target "' + $SourceItemTargetSingular + '" called "' + $TargetSearchByValue + '".')
                            }
                        }
                    }
                }
            }
            Else
            {
                Write-Error ('Unable to find the "' + $Type + '" called "' + $SourceItemSearchByValue + '".')
            }
        }
        Catch
        {
            Invoke-Command -ScriptBlock:($ScriptBlock_TryCatchError) -ArgumentList:($_, $true) -NoNewScope
        }
    }
    End
    {
        If ($Results)
        {
            $HiddenProperties = @('httpMetaData')
            Return Hide-ObjectProperty -Object:($Results) -HiddenProperties:($HiddenProperties)
        }
    }
}
