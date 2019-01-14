Function Get-JCPolicyTargetSystem
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName, Position = 0)][ValidateNotNullOrEmpty()][Alias('_id', 'id')][String]$PolicyID,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName, Position = 1)][ValidateNotNullOrEmpty()][String]$PolicyName
    )
    begin
    {

        Write-Verbose 'Verifying JCAPI Key'
        if ($JCAPIKEY.length -ne 40) {Connect-JConline}

        Write-Verbose 'Populating API headers'
        $hdrs = @{

            'Content-Type' = 'application/json'
            'Accept'       = 'application/json'
            'X-API-KEY'    = $JCAPIKEY

        }

        if ($JCOrgID)
        {
            $hdrs.Add('x-org-id', "$($JCOrgID)")
        }

        Write-Verbose 'Initializing RawResults and resultsArrayList'
        $RawResults = @()
        $resultsArrayList = New-Object System.Collections.ArrayList
    }
    process
    {
        $RawResults = @()
        If ($PolicyName)
        {
            $PolicyId = Get-JCPolicy | Where-Object {$_.name -eq $PolicyName}
            If (!($PolicyId))
            {
                Throw ('Policy name "' + $PolicyName + '" does not exist. Run "Get-JCPolicy" to see a list of all your JumpCloud policies.')
            }
        }
        $URL = "$JCUrlBasePath/api/v2/policies/$PolicyID/systems"
        Write-Verbose 'Populating SystemDisplayNameHash'
        $SystemDisplayNameHash = Get-Hash_SystemID_DisplayName
        Write-Verbose 'Populating SystemIDHash'
        $SystemHostNameHash = Get-Hash_SystemID_HostName
        $RawResults = Invoke-JCApiGet -URL:($URL)
        foreach ($result in $RawResults)
        {
            $Policy = Get-JCPolicy | Where-Object {$_.id -eq $PolicyID}
            if ($Policy)
            {
                $PolicyName = $Policy.Name
                $SystemID = $result.id
                $Hostname = $SystemHostNameHash.($SystemID )
                $DisplayName = $SystemDisplayNameHash.($SystemID)
                $OutputObject = [PSCustomObject]@{
                    'PolicyID'    = $PolicyID
                    'PolicyName'  = $PolicyName
                    'SystemID'    = $SystemID
                    'DisplayName' = $DisplayName
                    'HostName'    = $Hostname
                }
                $resultsArrayList.Add($OutputObject) | Out-Null
            }
            Else
            {
                Throw "Policy does not exist. Run 'Get-JCPolicy' to see a list of all your JumpCloud policies."
            }
        } # end foreach
    } # end process
    end
    {
        If ($resultsArrayList)
        {
            Return $resultsArrayList
        }
    }
}
