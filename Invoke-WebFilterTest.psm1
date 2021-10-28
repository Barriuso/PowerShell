
Function Invoke-WebFilterTest{

    # Invoke-WebFilterTest
    # Author: scott sutherland
    # Description The basic idea is to build out a quick script to check for access to code repositories, file shares, and online clipboards used by common malware. 
    # Note: This is a very basic PoC.  Ideally it would be nice to include common web filter categories and summary data in output. Also, runspaces for larger lists.
    # Note: should test access to known blacklisted site
    # Note: should test access to uncategorized site
    # Note: should test more categories
    # Note: Should add a shorter timeout
    
    # Example Commands:
    <#
      
      # Checks access to default sites, but doesn't authenticate with the current user's credentials
      Invoke-WebFilterTest -Verbose

      # Checks access to default sites, and authenticates with the current user's credentials
      Invoke-WebFilterTest -Verbose -UseCurrentUserContext
      
      # Checks access to default sites, custom sites, and authenticates with the current user's credentials
      Invoke-WebFilterTest -Verbose -UseCurrentUserContext -$ListPath c:\temp\urls.txt
      
      # Checks access to default sites, but doesn't authenticate with the current user's credentials
      # Writes output to a file
      Invoke-WebFilterTest -Verbose | Export-Csv -NoTypeInformation c:\temp\webfiltertest.csv
          
    #>

    [CmdletBinding()] 
    param
    (
        [string]$ListPath,
        [Switch]$UseCurrentUserContext
    )

    Begin
    { 
        # Create data table for list of block strings
        $BlockStrings = new-object System.Data.DataTable
        $BlockStrings.Columns.Add("Product") | Out-Null
        $BlockStrings.Columns.Add("String") | Out-Null

        # Add block strings
        $BlockStrings.rows.add("Barracuda","The link you are accessing has been blocked by the Barracuda Web Filter") | Out-Null 
        $BlockStrings.rows.add("Blue Coat","Blue Coat Systems") | Out-Null
        $BlockStrings.rows.add("Blue Coat","Your request was denied because of its content categorization:") | Out-Null
        $BlockStrings.rows.add("Web Filter","This page is blocked because it violates network policy") | Out-Null
        $BlockStrings.rows.add("FortiGuard","This web page is blocked because it violates network policy.") | Out-Null
        $BlockStrings.rows.add("IBoss","Access to the requested site has been restricted due to its contents.") | Out-Null
        $BlockStrings.rows.add("SonicWall","This site has been blocked by the network.") | Out-Null
        $BlockStrings.rows.add("SonicWall","The site has been blocked by the network") | Out-Null  
        $BlockStrings.rows.add("UnTangled","This web page is blocked because it violates network policy.") | Out-Null    
        $BlockStrings.rows.add("Unknown","URL Category Warning Acknowledgement") | Out-Null
        $BlockStrings.rows.add("McAfee Web Gateway","McAfee Web Gateway") | Out-Null
        $BlockStrings.rows.add("McAfee Web Gateway","This website was blocked because of the site’s category and/or reputation.") | Out-Null
        $BlockStrings.rows.add("ZScaler","Internet Security by Zscaler") | Out-Null
        $BlockStrings.rows.add("Palo Alto","Blocked Request: URL Policy Violation") | Out-Null

        # Create data table for list of target websites
        $WebSites = new-object System.Data.DataTable
        $WebSites.Columns.Add("URL") | Out-Null

        # Add target websites
        $WebSites.rows.add("https://bitbucket.org/") | Out-Null
        $WebSites.rows.add("https://pastebin.com/") | Out-Null
        $WebSites.rows.add("https://github.com/") | Out-Null
        $WebSites.rows.add("https://www.dropbox.com") | Out-Null
        $WebSites.rows.add("https://www.mediafire.com/") | Out-Null
        $WebSites.rows.add("http://www.4shared.com/") | Out-Null
        $WebSites.rows.add("https://www.google.com/drive/") | Out-Null
        $WebSites.rows.add("https://onedrive.live.com/") | Out-Null
        $WebSites.rows.add("https://www.icloud.com/") | Out-Null
        $WebSites.rows.add("http://box.com") | Out-Null
        $WebSites.rows.add("http://www.zippyshare.com/") | Out-Null
        $WebSites.rows.add("http://uploaded.net/") | Out-Null
        $WebSites.rows.add("https://www.sendspace.com/") | Out-Null
        $WebSites.rows.add("http://www.filecrop.com/") | Out-Null
        $WebSites.rows.add("http://pastebin.com/") | Out-Null    
        $WebSites.rows.add("http://www.filedropper.com/") | Out-Null
        $WebSites.rows.add("http://FriendPaste.com") | Out-Null
        $WebSites.rows.add("http://CopyTaste.com")| Out-Null
        $WebSites.rows.add("http://Cl1p.net")| Out-Null
        $WebSites.rows.add("http://ShortText.com")| Out-Null
        $WebSites.rows.add("http://TextSave.de")| Out-Null
        $WebSites.rows.add("http://TextSnip.com")| Out-Null
        $WebSites.rows.add("http://TxtB.in")| Out-Null
        $WebSites.rows.add("https://raw.githubusercontent.com/NetSPI/PowerShell/master/Invoke-WebFilterTest.psm1") | Out-Null
        $WebSites.rows.add("https://gist.githubusercontent.com/nullbind/75a8fa02ba8d0a6f028cfb21c300e1e2/raw/0319cabbbd69c7bbd013850f1bc65188986b4636/MiniPowerUpSQL.psm1") | Out-Null

        # Check for target websites from provide file path
        If ($ListPath){ 
            if (Test-Path $ListPath){
                Write-Verbose "Path is valid."
                Get-Content $ListPath | 
                ForEach-Object {
                    $WebSites.rows.add($_) | Out-Null
                }
            }else{
                Write-Verbose "List path is invalid."
            }
        }

        # Print count of target websites
        $WebSiteCount = $WebSites | Measure-Object -Line | Select-Object Lines -ExpandProperty Lines
        Write-Verbose "Testing access to $WebSiteCount websites..."
     
        # Create data table results
        $ResultsTbl = new-object System.Data.DataTable
        $ResultsTbl.Columns.Add("WebSite") | Out-Null
        $ResultsTbl.Columns.Add("Accessible") | Out-Null
        $ResultsTbl.Columns.Add("WebFilter") | Out-Null
    }

    Process
    {    
        # Setup http handler
        $HTTP_Handle = New-Object net.webclient               

        # Check for website access  
        $WebSiteCount2 = $WebSiteCount + 1 
        $WebSites | 
        ForEach-Object {
            $WebSiteCount2 = $WebSiteCount2 - 1 
            $CurrentUrl = $_.URL 
            $Block = 0
            try {
               
                # Enable passthrough authentication to authenticate to the proxy using your current user context;)
                if($UseCurrentUserContext)
                {
                    $HTTP_Handle.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                }

                # Reduce ssl requirements
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                # Send HTTP request and get results
                $Results = $HTTP_Handle.DownloadString("$CurrentUrl")                

                # Check for blocks
                $BlockStrings | 
                ForEach-Object {
                    $CurrentBlockString = $_.String
                    $WebFilterProduct = $_.Product
                    if($Results -like "*$CurrentBlockString*"){
                        Write-Verbose "$WebSiteCount2 of $WebSiteCount - Status: Blocked ($WebFilterProduct) $CurrentUrl"
                        $ResultsTbl.Rows.Add($CurrentUrl,"No","$WebFilterProduct") | Out-Null
                        $Block = 1
                    }
                }
            
                # Check for access
                if($Block -eq 0){
                    Write-Verbose "$WebSiteCount2 of $WebSiteCount - Status: Allowed $CurrentUrl"
                    $ResultsTbl.Rows.Add($CurrentUrl,"Yes","NA") | Out-Null
                    return
                }
            }catch{

                 $ErrorMessage = $_.Exception.Message
                 Write-Verbose "$WebSiteCount2 of $WebSiteCount - Status: Request Failed - $ErrorMessage - $CurrentUrl"
                 $ResultsTbl.Rows.Add($CurrentUrl,"Request Failed","NA") | Out-Null
            }
        }
    }

    End
    {
        # Return table with results
        $ResultsTbl
    }
}
