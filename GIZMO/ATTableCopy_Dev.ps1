#$ScriptFileDir = "\\192.168.1.52\CA-7\Data_Services_DBA_AutoTicket\"
#$RequestDetailID = 27

Function AT_SQLTableCopy 
{
Param
    (
        [Parameter(Mandatory=$true, Position=0,
        HelpMessage="Script File Dir")]
        [ValidateNotNullOrEmpty()]
        [string] $ScriptFileDir ,

        [Parameter(Mandatory=$true, Position=1,
        HelpMessage="Request Detail ID")]
        [ValidateNotNullOrEmpty()]
        [int] $RequestDetailID ,

        [Parameter(Mandatory=$true, Position=2,
        HelpMessage="Account ID")]
        [ValidateNotNullOrEmpty()]
        [string] $ActIDAD,

        [Parameter(Mandatory=$true, Position=3,
        HelpMessage="Acount Key")]
        [ValidateNotNullOrEmpty()]
        [string] $ActKeyAD, 

        [Parameter(Mandatory=$true, Position=2,
        HelpMessage="Account ID")]
        [ValidateNotNullOrEmpty()]
        [string] $ActIDSQL ,

        [Parameter(Mandatory=$true, Position=3,
        HelpMessage="Acount Key")]
        [ValidateNotNullOrEmpty()]
        [string] $ActKeySQL 

    )

try {
    # Load Active Directory module
    #Set-ExecutionPolicy Bypass
    #if ( -NOT (get-module SQLServer)){Import-Module SQLServer}  else {"SQLServer Loaded"}
    Set-DbatoolsConfig -Name Import.SqlpsCheck -Value $false -PassThru | Register-DbatoolsConfig
    if ( -NOT (get-module DBATools)){Import-Module DBATools | Out-Null }  else {"DBATools Loaded" | Out-Null } 
    
    #Get-ChildItem -Recurse "C:\Program Files\WindowsPowerShell\Modules\dbatools" | Unblock-File   # Unblock DLLs
    #Get-ChildItem -Recurse "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\dbatools" | Unblock-File   # Unblock DLLs
    # Get-Command -Module  DBATools  # Help me!
    # Get-Command -Module  SQLServer  # Help me!
    #$env:PSModulePath

    # Set default variables / qtys  - advoiding null values on purpose.
    $ATDataBase = "AutoTicket_Dev"
    $NewSourceeQTY = -1     # Set to known bad values 
    $NewTargetQTY  = -1     # Set to known bad values 
    $TargetQTYBase = -1     # Set to known bad values 
    $Result= $null          # 0 = Failure, 1 = Success
    $Comment = 'Started'    # User friendly comment requarding activity or pass-along-valure to be used within a process flow.
                            # Why so many!!!:  Used for Initial testing / resolving failures.   Extra comments used to better understand where things went sideways. Comment gets written backt to AT system results table.
    # Set AT Hub SQL Instance and Environment Level Database
    $ATInstance = "P054GZMSQLS01.AMER.EPIQCORP.COM" #"AutoTicketHub"
    $ATInstance = "P054GZMSQLS01" #"AutoTicketHub"

    ## Testing purposes
    #$CUser = $env:UserName
    #Write-Verbose "Current User: $CUser"
    $Comment = "Set Creds"

    $PwdAD = ConvertTo-SecureString "$ActKeyAD" -AsPlainText -Force
    $IDAD = New-Object System.Management.Automation.PsCredential($ActIDAD, $PwdAD)
    Write-Verbose "AD credentials established.  $IDAD"  

    $PwdSQL = ConvertTo-SecureString "$ActKeySQL" -AsPlainText -Force  #$ActKeySQL
    $IDSQL = New-Object System.Management.Automation.PSCredential($ActIDSQL,$PwdSQL)
    Write-Verbose "AD credentials established.  $IDSQL"  
    $Comment = "Success: Set Creds"
    
    #Ensure staring variables are empty.
    $ScriptFile = $null
    $CopyDataOnly = $null 

    # Gather Request Details from AutoTicket Database.
    $queryReqDetail =  "SELECT 
        [ATRequestDetailID]     `
       ,[ATRequestID]           `
       ,[RunOrder]              `
       ,[RequestTask]           `
       ,[TargetInst]            `
       ,[TargetDB]              `
       ,[ScriptFile]            `
       ,[SourceInst]            `
       ,[SourceDB]              `
	   ,[TargetTable]           `
	   ,[TargetSchema]          `
	   ,[SourceSchema]          `
       ,[CopyDataOnly]          `
    FROM [ATRequestDetail] WHERE [ATRequestDetailID] =  $RequestDetailID"  
    # Set initial Varibles 
    $Comment = "Get Request Info."
    $ATReqDtl = $null 
    $ATReqDtl = Invoke-DbaQuery -SqlInstance $ATInstance -Database $ATDataBase -Query $queryReqDetail -SqlCredential $IDAD -As DataSet 
    $data = $ATReqDtl.Tables[0]
    foreach ( $data_item in  $data.Rows ) {
            $ATRequestDetailID  = $data_item[0]
            $ATRequestID        = $data_item[1]
            $RunOrder           = $data_item[2]
            $RequestTask        = $data_item[3]
            $TargetInst         = $data_item[4]
            $TargetDB           = $data_item[5]
            $ScriptFile         = $data_item[6]
            $SourceInst         = $data_item[7]
            $SourceDB           = $data_item[8]
            $TargetTBL          = $data_item[9]
            $TargetSchema       = $data_item[10]
            $SourceSchema       = $data_item[11]
            $CopyDataOnly       = $data_item[12]
    }
    Write-Verbose "Table-Copy Query fileName: $ScriptFile"
    Write-Verbose "Copy Data Only Var: $CopyDataOnly"
    if ( $ScriptFile -eq $NULL) {
        Write-Verbose "Missing Table-Copy Query fileName in Request Detail Table (ATRequestDetail)."
        $Result= 0   # 0 = Failure, 1 = Success
        $Comment = "ERROR:  Table-Copy process - Missing Table-Copy Query fileName in Request Detail Table (ATRequestDetail)."
        break
    }
    
    if ( $CopyDataOnly -eq $NULL) {
        Write-Verbose "Missing Table-Copy Query fileName in Request Detail Table (ATRequestDetail)."
        $Result= 0   # 0 = Failure, 1 = Success
        $Comment = "ERROR:  Table-Copy process - Missing CopyDataOnl data variable in Request Detail Table (ATRequestDetail)."
        break
    }
    $Comment = "Request Task Info gathered."
        
    $MsgTarget = "[$TargetInst].[$TargetDB].[$TargetSchema].[$TargetTBL]"
    $MsgSource = "[$SourceInst].[$SourceDB] - Script File: $ScriptFile"
    
    $CUser = $env:UserName
    Write-Verbose "Current User: $CUser"
    $Comment = "Current User: " +$CUser

    # Establish Powershell Session to source and target servers.
    #$s = New-PSSession -ComputerName 

    # Establish UNC Path to query drop folder to reatd query file contents.   
    #   Needed since script is being call from SQL as SQL Engine service account. 
    #   For this funthion to be success, it needs this exra help! 
    if ( "\" -eq ($ScriptFileDir.Substring($ScriptFileDir.Length - 1) ) ) {
        $NetUseDir = $ScriptFileDir.Substring(0,$ScriptFileDir.Length-1) }
    else { $NetUseDir = $ScriptFileDir }
    $pathExists = Test-Path -Path $NetUseDir
    $Comment = "Test-path test #1 ("+$NetUseDir+"): "+$pathExists
    if ($pathExists -eq $false) {
    net use $NetUseDir $ActKeyAD  /user:$ActIDAD
    }
    try {
    $pathExists = Test-Path -Path $NetUseDir
    $Comment = "Test-path test #2 ("+$NetUseDir+"): "+$pathExists
    }
    catch {
        Write-Verbose "Path access still not working!!!!"
        $Result= 0   # 0 = Failure, 1 = Success
        $Comment = "ERROR:  Table-Copy process - Not able to Access Query File Directory:  " + $NetUseDir
        break
    }
     
    
    # Get Source Query  NOTE:  This is double checking.   The overall process does a "script file exists check"  May / May not keep in future.
    $SourceQuery = $null
    $SourceQuery = [IO.File]::ReadAllText("$ScriptFileDir$ScriptFile"  ) #File location and file name comes from Auto Ticket database tables
    Write-Verbose "Script-File Contents; $SourceQuery"
    if ( $SourceQuery -eq $NULL) {
        Write-Verbose "Not able to locate and load Script file ($ScriptFileDir$ScriptFile)"
        $Result= 0   # 0 = Failure, 1 = Success
        $Comment = "ERROR:  Table-Copy process - Not able to locate and load Script file (" + $ScriptFileDir + $ScriptFile + ")"
        break
    } 
    $Comment = "Source Query Info gathered."  # Milestone marker.

    # OK to start Processing work.
    $A = 0   # Simple loop counter - really not a loop, just used to control overall process control. 
    DO {  # does target table exist?
        <#
        # Replaced - Decision to never allow over-write maded even if it is a development environment.
        $ATInstance = "P054SQLMGMT03.epiqcorp.com\SQLADMIN" #"AutoTicketHub"
        $ATDataBase = "AutoTicket"
        # IMPORTANT SAFE GUARD:   Determine Target Instance Enviornment Level.
        # DO NOT ALLOW ANY TABLE IN PROD TO BE OVERWRITTEN!!!!!!!!!
        $queryInstEnvLvl = "SELECT [AppEnv] FROM [ATSQLInstances] WHERE [Instance_Name] = N'$TargetInst' and [IsActive] = 1"  #$TargetTBL
        $EnvLvl = $null #'Table not here!'
        $EnvLvl = Invoke-DbaQuery -SqlInstance $ATInstance -Database $ATDataBase -Query $queryInstEnvLvl  -As SingleValue   # DataSet  #-AS PSObjectArray# -SqlCredential $containerCred
        if ($EnvLvl -eq $null) {
            Write-Verbose 'Unable to verify Target Instance Enviornment Level, cannot proceed with Table-Copy process.'
            $Result= 0   # 0 = Failure, 1 = Success
            $Comment = 'ERROR:  Table-Copy process unable to verify Target Instance Enviornment Level, cannot proceed with Table-Copy process.'
            break
            }
        # Evaluate Environment Level / set internal $IsProd bool flag.  Controls if table can exist / be overwritten.
        #$EnvLvl = 'ECA_Staging'
        #$EnvLvl = 'ECA_Prod'
        # Set $IsProd default value.  
        IF ($EnvLvl -match 'prod' ) { $IsProd = $true }
        else { $IsProd = $false } 
        Write-Verbose "IsPROD:  $IsProd" 
        $IsProd = $true 
        #>

        # Target Table Validations  -  Determine if table eixsts - Safety feature
        $Comment = "Starting Table Validations."
        $queryTargetTbLExists = "SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'$TargetTBL'"  #$TargetTBL
        $TbLExists = $null  # Set inital Variable and value = 'Table not here!'
        $TbLExists = Invoke-DbaQuery -SqlInstance $TargetInst -Database $TargetDB -Query $queryTargetTbLExists -SqlCredential $IDAD  -As SingleValue   # DataSet  #-AS PSObjectArray# -SqlCredential $containerCred
        Write-Verbose  "Target-Table Exists Check Value: $TbLExists   - CopyDataOnly Value:  $CopyDataOnly"
        if( ($TbLExists -ne $null) -and ($CopyDataOnly-eq $false) ) {  #Write-Host 'Table exists'
             Write-Verbose  "if( (TbLExists -ne null) -and (CopyDataOnly-eq false) )"
             Write-Verbose "Table ($TargetTBL) exists!!! - By design, over-write existing tables is not allowed."
             $Result= 0   # 0 = Failure, 1 = Success
             $Comment = "ERROR:  Table-Copy process - Table (" + $TargetTBL + ") exists!!! - By design, over-write existing tables is not allowed.  Target Info: " + $MsgTarget
             break
        }
        # Target Table Validations  - Make certian table exists for all Copy Data Only requests, regardless of environment level.
        if ( ($CopyDataOnly-eq $true) -and ($TbLExists -eq $null) ) { # Abort - Table must be present
            Write-Verbose  "if ( (CopyDataOnly-eq true) -and (TbLExists -eq null) )"
            Write-Verbose  "Table ($TargetTBL) Does Not exist - continuation of request not allowed."
            $Result= 0   # 0 = Failure, 1 = Success
            $Comment = "ERROR:  Table-Copy process - Copy Data Only requested, but table (" + $TargetTBL + ") does not exist! Cannot continuation request as requested. Target Info: " + $MsgTarget
            break
        }
        $Comment = "Table Validations successfull; Starting record Qty Validations."

        # Establish base line. 
        #Capture Source Query Rec QTY
        $SourceQryQTY = Invoke-DbaQuery -SqlInstance $SourceInst -Database $SourceDB -Query $SourceQuery -SqlCredential $IDAD -As SingleValue  #-AS PSObjectArray# -SqlCredential $containerCred
        $SourceQTY = $SourceQryQTY.Count
        #$SourceQTY  # Testing
        Write-Verbose "Source Query Rec Qty:  $SourceQTY Target Instance: $TargetInst Target Database: $TargetDB  Target Schema: $TargetSchema  Target Table: $TargetTBL  CopyDataOnly: $CopyDataOnly  TbLExists: $TbLExists"  
        # Set Target Qty Qurery  NOTE:  Do not put Instance and DB Name in query.  Invoke-DBAQuery specifies it seperately.
        $TargetQTY = "select count(*) FROM [$TargetInst].[$TargetDB].[$TargetSchema].[$TargetTBL]"
        $TargetQTY = "select count(*) FROM [$TargetSchema].[$TargetTBL]"
        #Capture Target Base Rec QTY
        if (($CopyDataOnly-eq $true) -and ($TbLExists -ne $null) ) {  # Toggle switch for -AutoCreateTable variable  
             Write-Verbose "If Test: if ((CopyDataOnly -eq true) -and (TbLExists -eq true) )"
             $TargetQTYBase = Invoke-DbaQuery -SqlInstance $TargetInst -Database $TargetDB -Query $TargetQTY -SqlCredential $IDAD -As SingleValue  #-AS PSObjectArray# -SqlCredential $containerCred
             Write-verbose "Target Qty Base Result: $TargetQTYBase  Target Info: $MsgTarget"
        }
        else  {  # Adjust Target base QTY.
             $TargetQTYBase = 0
        }
        Write-verbose "Target DB Base Rec Qty: $TargetQTYBase"
        
        # Process the table-copy move.
        #$TestAccess = $null

        #Step 1 - get data
        <# Attempt to catch log-in failuures.  Currently does not work 4/1/2021
        $TestAccess = $null
        $WarnVar = 'warnvar'
        $e = "NoError"
        $i = "info"
        Write-verbose "Warning test: $WarnVar" 
        $TargetQTY2 = "select count(*) FROM [dbo].[AD_Domains_ATTest5]"
        $TestAccess = Connect-DbaInstance -SqlInstance $TargetInst  -Database  $TargetDB -SqlCredential $IDAD -ErrorVariable $e -WarningVariable:$warnvar -InformationVariable $i -Verbose #-SqlCredential 'XXXXXXX'
        #$TestAccess = Invoke-DbaQuery -SqlInstance $TargetInst -Database $TargetDB -Query $TargetQTY2 -SqlCredential $IDAD -As SingleValue 
        Write-verbose "Warning test: $WarnVar" 
        Write-verbose "Warning test: $TestAccess"
        Write-verbose "Warning test: $e"
        Write-verbose "Warning test: $i"
        $Comment = $warnvar
        break
        
        if ($TestAccess -eq $Null ) {
           $Result= 0   # 0 = Failure, 1 = Success
           $Comment = "ERROR:  Table-Copy process - Unablet to connect to Target Database (" + $TargetDB + ") on Target Server (" + $TargetInst + ")." 
           Write-verbose "Warning test: $WarnVar" 
           $Comment = $warnvar
           break
        }
        if ($WarnVar -ne 'warnvar' ) {
           $Result= 0   # 0 = Failure, 1 = Success
           $Comment = "ERROR:  Table-Copy process - " + $WarnVar 
           #$Comment = $TestAccess
           break
        }
        #>

        $Comment = "Starting Data Transfer."
        Write-Verbose "Starting Data Transfer."
        try {  # Transfer Data
            $CopyData = $null

            $TestAccess2 = $null
            $WarnVar = 'warnvar'
            $TCInfo = $null

            # #Step 1 - get data
            # $dataset = Invoke-DbaQuery -SqlInstance $SourceInst -Database $SourceDB -Query $SourceQuery -SqlCredential $IDAD -As DataSet -Verbose  #-AS PSObjectArray# -SqlCredential $containerCred
            $Comment = "Location test #1"
            $TC = Invoke-DbaQuery -SqlInstance $SourceInst -Database $SourceDB -Query $SourceQuery -SqlCredential $IDAD -As DataSet -Verbose
            #$TC.table[0]
            $Comment = "Location test #2a"
            Write-Verbose "Location test #2a"
            Write-Verbose "TC Test:  $TC.table[0]" 
            #Write-Verbose "Write-DbaDbTableData Result:  $TCInfo"   

            #$tpwd = ConvertTo-SecureString "Am3rAut0t1ck3t2019!" -AsPlainText -Force
            #$ATCTst = New-Object System.Management.Automation.PSCredential("svc_autoticket",$tpwd)
            #$IDSQL

            #if ($CopyDataOnly -eq $false) {$ACT = $true} else {$ACT = $false} 
            if ($CopyDataOnly -eq $false) 
            {
            $Datetime = [SYSTEM.datetime]::Now.ToString("yyyyMMdd_hhmmss") 
            $scriptTBLfile = "D:\PowerShell\AutoTicket\TableScripts\" + $TargetTBL +"_"+ $Datetime + "_CreateTable" + ".sql"
            $options = New-DbaScriptingOption
            $options.ScriptSchema = $true
            $options.DriAllConstraints =$true
            $Options.Indexes = $true
            $Options.ClusteredIndexes = $true
            $Options.NonClusteredIndexes = $true
            $Options.IncludeIfNotExists = $true;
            
            Get-DbaDbSchema -SqlInstance $SourceInst -Database $SourceDB -Schema $SourceSchema -SqlCredential $IDAD | Export-DbaScript -FilePath $scriptTBLfile -ScriptingOptionsObject $options
            Get-DbaDbTable -SqlInstance $SourceInst -Database $SourceDB -Table $TargetTBL -SqlCredential $IDAD  | Export-DbaScript -FilePath $scriptTBLfile -ScriptingOptionsObject $options -Append
            Invoke-DbaQuery -SqlInstance $TargetInst -Database $TargetDB -SqlCredential $IDAD -File $scriptTBLfile 
            #Get-ChildItem -Path $scriptTBLfile -File -Recurse | Remove-Item
            $ACT = $false            
            } 
            else 
            {
            $ACT = $false
            } 
            ##$TestAccess1 = $TC | Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $IDAD  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar| Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $IDAD  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar
            #$TestAccess1 = $TC | Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $ATCTst -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar| Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $IDAD  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar
            $TestAccess1 = $TC | Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $IDSQL -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar| Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $IDAD  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar
            $Comment = "Location test #2b"
            Write-Verbose "Location test #2b"
            Write-Verbose "Write-DbaDbTableData Result:  $TestAccess1" 
            #Write-Verbose "Write-DbaDbTableData Result:  $TCInfo"      
            #break
            $Comment = "Location test #2c"
            Write-Verbose "Location test #2c"`

            <#
            if ($CopyDataOnly -eq $false) {$ACT = $true} else {$ACT = $false} 
            $TestAccess2 = Invoke-DbaQuery -SqlInstance $SourceInst -Database $SourceDB -Query $SourceQuery -SqlCredential $IDAD -As DataSet -Verbose | Write-DbaDbTableData  -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $IDAD  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar
            Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $ATCTst -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar| Write-DbaDbTableData -InformationVariable $TCInfo -BatchSize 10000 -SqlInstance $TargetInst -SqlCredential $IDAD  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$ACT -Verbose  #-WarningVariable WarnVar
            $Comment = "Location test #2"
            Write-Verbose "Write-DbaDbTableData Result:  $TestAccess2" 
            Write-Verbose "Write-DbaDbTableData Result:  $TCInfo"      
            $Comment = "Location test #2d"
            Write-Verbose "Location test #2d"

             if ($TestAccess2 -ne $Null ) {
               $Result= 0   # 0 = Failure, 1 = Success
               $Comment = "ERROR:  Table-Copy process - Unable to connect to Target Database (" + $TargetDB + ") on Target Server (" + $TargetInst + ")." 
               $Comment = "Location test #3"
               Write-Verbose "Location test #3"
               break
            }
            #>
        }   # Transfer Data       
        catch {
           $CopyData = "ERROR:  Table-Copy process - " +$TestAccess2
           $Result= 0   # 0 = Failure, 1 = Success
           $Comment = "ERROR:  Table-Copy process - Var TestAccess2 = : " +$TestAccess2
           Write-Verbose "ERROR:  Table-Copy process - $CopyData"
           $Comment = "Location test #4"
           Write-Verbose "Location test #4"
           break
        } # Transfer Data 

        $Comment = "Complete: Data Transfer."
        Write-Verbose "Complete: Data Transfer."
        #if ($WarnVar -ne 'warnvar' ) {
        #   $Result= 0   # 0 = Failure, 1 = Success
        #   $Comment = "ERROR:  Table-Copy process - " + $WarnVar 
        #   #$Comment = $TestAccess
        #   break
        #}

       <#
        try {
            $CopyData = $null
            $CopyData = Invoke-DbaQuery -SqlInstance $SourceInst -Database $SourceDB -Query $SourceQuery -As DataSet | Write-DbaDbTableData -BatchSize 10000 -SqlInstance $TargetInst  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$CopyDataOnly | Select output 
            $Result= 0   # 0 = Failure, 1 = Success
            $CopyData
            $Comment = $CopyData
            #break
            throw
        }
        catch {
          $Result= 0   # 0 = Failure, 1 = Success
          $Comment = "ERROR:  Table-Copy process - " +$CopyData #$_.ErrorDetails
          Write-Verbose "ERROR:  Table-Copy process - "$CopyData #$_.ErrorDetails
          break
        }  
        #>
        #$dataset | Write-DbaDbTableData -BatchSize 10000 -SqlInstance $TargetInst  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$CopyDataOnly
        <#
        #if ($IsProd -eq $true) { 
            if ($CopyDataOnly-eq $false)    # Toggle switch for -AutoCreateTable variable  very important!!!!  when used, it allows table to be created, if not used deos not allow table to be created.
               { $dataset | Write-DbaDbTableData -BatchSize 10000 -SqlInstance $TargetInst  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity -AutoCreateTable:$CopyDataOnly
               }  #-SqlCredential $containerCred }
            else
               { $dataset | Write-DbaDbTableData -BatchSize 10000 -SqlInstance $TargetInst  -Database $TargetDB -Table $TargetTBL -Schema $TargetSchema  -bulkCopyTimeOut 5000  -KeepNulls -KeepIdentity  }  #-SqlCredential $containerCred }
        #}    
        #>
       
        $Comment = "Start: Data Transfer validation."

        # Capture New Rec QTY's
        $NewTargetQTY = Invoke-DbaQuery -SqlInstance $TargetInst -Database $TargetDB -SqlCredential $IDAD  -Query $TargetQTY  -As SingleValue  #-AS PSObjectArray# -SqlCredential $containerCred
        Write-verbose "New Target Table Qty: $NewTargetQTY    Target Table Base: $TargetQTYBase"
        $Comment = "New Target Table Qty: " + $NewTargetQTY + " Target Table Base: " + $TargetQTYBase
        
        $Comment = "Location test 7"
        Write-verbose  "Location test 7"
        Write-Verbose "SourceQty: $SourceQTY  TargetQTYBase $TargetQTYBase   NewTargetQTY: $NewTargetQTY"
        # verfiy record counts
        if ($CopyDataOnly -eq $false)
            {  Write-Verbose "if (CopyDataOnly -eq false)"
               write-verbose "Resulte: True -and if (SourceQTY -ne NewTargetQTY)" 
              if ($SourceQTY -ne $NewTargetQTY) 
                 { Write-Verbose "Result = True - ERROR: Target Table ($TargetTBL) Record count ($NewTargetQTY) Does Not equal Source Table Record Count ($SourceQTY)" 
                   $Result= 0   # 0 = Failure, 1 = Success
                   $Comment = "ERROR:  Table-Copy process - Target Table (" + $TargetTBL + ") Record count (" + $NewTargetQTY + ") Does Not equal Source Table/Query Record Count (" + $SourceQTY + ")" 
                   break
                 }
              else
                 { Write-Verbose "Result = false - Success: Record counts Match: Target Table ($NewTargetQTY):  $NewTargetQTY  Source Table/Query Record Count:   $SourceQTY" 
                   $Result= 1   # 0 = Failure, 1 = Success
                   $Comment = "SUCCESS:  Table-Copy process - Record counts Match: Target Table (" + $TargetTBL + "): " +$NewTargetQTY + "  Source Table/Query record Count:   " + $SourceQTY 
                   break
                 }
            }
        else  # if ($CopyDataOnly-eq $true)  
            { write-verbose "if (CopyDataOnly -eq false) 'Else'"
              if (($SourceQTY+$TargetQTYBase) -ne $NewTargetQTY) 
                 { Write-Verbose "- and -if ((SourceQTY+TargetQTYBase) -ne NewTargetQTY)"
                   Write-Verbose "Result = True - ERROR: Target Table ($TargetTBL) Record count: $NewTargetQTY  Does Not equal Source Table Record Count ($SourceQTY)" 
                   $Result= 0   # 0 = Failure, 1 = Success
                   $Comment = "ERROR:  Table-Copy process - Target Table (" + $TargetTBL + ") Record count: " + $NewTargetQTY + "  Does Not equal prior Target Table Rec count (" + $TargetQTYBase + ") plus Source Qery Record Count (" + $SourceQTY + ")" 
                   break
                 }
              else
                 { Write-Verbose "Result = false - SUCCESS:  Record Qty move Successful: $SourceQTY Records Added to table $TargetTBL." 
                   $Result= 1   # 0 = Failure, 1 = Success
                   $Comment = "SUCCESS:  Table-Copy process - Record Qty move Successful:  " + $SourceQTY +" Records Added to table " + $TargetTBL + ".  Before Qty:  $TargetQTYBase   After Qty: $NewTargetQTY " 
                   break
                 }
            }
        $Comment = "End: Data Transfer validation."

        $A = 1  # Exit While loop
    } while ($A -le 0)
<#
    # Gather Request Details
    $TableCopyResults =  "UPDATE [ATRequestDetail] `
        SET [copyTableResult] =  $Result  `
            , [CopyTableComment] = '$Comment' `
    WHERE [ATRequestDetailID] =  $RequestDetailID"  
    $TableCopyResults
     
    #$ATReqDtl = $null #'Table not here!'
    $ATReqResult = Invoke-DbaQuery -SqlInstance $ATInstance -Database $ATDataBase -Query  $TableCopyResults  -As SingleValue #-AS PSObjectArray# -SqlCredential $containerCred
    $ATReqResult
 
  return ($Result,$Comment)
  Write-Host ''
#>
}
catch {
  $Result= 0   # 0 = Failure, 1 = Success
  #$Comment = $CopyData #$_.ErrorDetails 1
  Write-Verbose $CopyData #$_.ErrorDetails  1
}    
finally {
    # Gather Request Details
    #if ($Comment -eq $null) { $Comment = "ERROR:  Table-Copy - Un-Known."}
    $TableCopyResults =  "UPDATE [ATRequestDetail] `
        SET [copyTableResult] =  $Result  `
            , [CopyTableComment] = '$Comment' `
            , [ProcessStatus]    =  $Result  `
            , [ProcessComments]  = '$Comment' `
    WHERE [ATRequestDetailID] = $RequestDetailID"  
    #$TableCopyResults
     
    #$ATReqDtl = $null #'Table not here!'
    $ATReqResult = Invoke-DbaQuery -SqlInstance $ATInstance -Database $ATDataBase -SqlCredential $IDAD -Query  $TableCopyResults  -As SingleValue #-AS PSObjectArray# -SqlCredential $containerCred
    $ATReqResult
}
  return ($Result,$Comment)
  Write-Host ''

} # Function AT_SQLTableCopy  


# Testing below here
#AT_SQLTableCopy -ScriptFileDir '\\192.168.1.52\CA-7\Data_Services_DBA_AutoTicket\'  -RequestDetailID 27 -Verbose

<#
 $PS1result = AT_SQLTableCopy -ScriptFileDir $vSourceDir -RequestDetailID $ATRequestDetailID #-verbose  
 foreach ( $PS1Row in  $PS1result ) {
    $PS1Row
 }
 #>

# AT_SQLTableCopy # '\\192.168.1.52\CA-7\Data_Services_DBA_AutoTicket\' 24

<#  
$vSourceDir = "\\192.168.1.52\CA-7\Data_Services_DBA_AutoTicket\"
#$ProcessDir = $vSourceDir
$ATRequestDetailID = 24



 $PS1result = AT_SQLTableCopy -ScriptFileDir $vSourceDir -RequestDetailID $ATRequestDetailID  -ActID 'AMER\svc_AutoTicket' -ActKey 'Am3rAut0t1ck3t2019!' -Verbose 
 foreach ( $PS1Row in  $PS1result ) {
    $PS1Row
 }

$ATRequestDetailID = 24
 $PS1result = AT_SQLTableCopy -ScriptFileDir $vSourceDir -RequestDetailID $ATRequestDetailID -verbose  
 foreach ( $PS1Row in  $PS1result ) {
    $PS1Row
 }

$ATRequestDetailID = 25
 $PS1result = AT_SQLTableCopy -ScriptFileDir $vSourceDir -RequestDetailID $ATRequestDetailID -verbose  
 foreach ( $PS1Row in  $PS1result ) {
    $PS1Row
 }
$ATRequestDetailID = 26
 $PS1result = AT_SQLTableCopy -ScriptFileDir $vSourceDir -RequestDetailID $ATRequestDetailID -verbose  
 foreach ( $PS1Row in  $PS1result ) {
    $PS1Row
 }
$ATRequestDetailID = 27
 $PS1result = AT_SQLTableCopy -ScriptFileDir $vSourceDir -RequestDetailID $ATRequestDetailID -verbose  
 foreach ( $PS1Row in  $PS1result ) {
    $PS1Row
 }
$ATRequestDetailID = 28
 $PS1result = AT_SQLTableCopy -ScriptFileDir $vSourceDir -RequestDetailID $ATRequestDetailID -verbose  
 foreach ( $PS1Row in  $PS1result ) {
    $PS1Row
 }
#>
