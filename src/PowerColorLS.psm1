#Requires -Modules Terminal-Icons
$terminalIconsFolder = [System.IO.Path]::GetDirectoryName((Get-Module Terminal-Icons).path)
$theme 		= "devblackops"
$glyphs     = . $terminalIconsFolder/Data/glyphs.ps1
$iconTheme 	= Import-PowerShellDataFile "${terminalIconsFolder}/Data/iconThemes/$theme.psd1"
$colorTheme	= Import-PowerShellDataFile "${terminalIconsFolder}/Data/colorThemes/$theme.psd1"
. $terminalIconsFolder/Private/ConvertFrom-RGBColor.ps1

function Show-Help{
    Write-Host "Usage: PowerColorLs [OPTION]... [FILE]..."
    Write-Host "List information about files and directories (the current directory by default)."
    Write-Host "Entries will be sorted alphabetically if no sorting option is specified."
    Write-Host ""
    Write-Host "`t-a, --all`t`tdo not ignore hidden files and files starting with ."
    Write-Host "`t-l, --long`t`tuse a long listing format"
    Write-Host "`t-1`t`t`tlist one file per line"
    Write-Host "`t-d, --dirs`t`tshow only directories"
    Write-Host "`t-f, --files`t`tshow only files"
    Write-Host "`t-ds, -sds, --sds, --show-directory-size"
    Write-Host "`t`t`t`tshow directory size (can take a long time)"
    Write-Host ""
    Write-Host "sorting options:"
    Write-Host ""
    Write-Host "`t-sd, --sort-dirs, --group-directories-first"
    Write-Host "`t`t`t`tsort directories first"
    Write-Host "`t-sf, --sort-files, --group-files-first"
    Write-Host "`t`t`t`tsort files first"
    Write-Host "`t-t, -st, --st"
    Write-Host "`t`t`t`tsort by modification time, newest first"
    Write-Host ""
    Write-Host "general options:"
    Write-Host ""
    Write-Host "`t-h, --help`t`tprints this help"
}

function Get-OptionsResult{
    Param([array] $arguments)
    $options = @{
        oneEntryPerLine = $false
        showHiddenFiles = $false
        dirOnly = $false
        fileOnly = $false
        longFormat = $false
        dirsFirst = $false
        filesFirst = $false
        sortByModificationTime = $false
        showDirectorySize = $false
    }

    $get_optionsResult = @{
        continue = $true
        errorMessage = $null
        query = "."
    }

    if($arguments){
        foreach($arg in $arguments){
            if($null -ne $arg){
                $a = "$arg"
                $isPath = Test-Path -path $a
                if($isPath){
                    $get_optionsResult.query = $arg
                }else{
                    switch ($a) {
                        {(($a -eq "-h") -or ($a -eq "--h") -or ($a -eq "--help"))} {
                            Show-Help
                            $get_optionsResult.continue = $false
                            return $get_optionsResult
                       }
                        "-1" {
                             $options.oneEntryPerLine = $true
                        }
                        {(($a -eq "-a") -or ($a -eq "--all") -or ($a -eq "--almost-all"))} {
                            $options.showHiddenFiles = $true
                        }
                        {(($a -eq "-d") -or ($a -eq "--dirs") -or ($a -eq "--directory"))} {
                            $options.dirOnly = $true
                        }
                        {(($a -eq "-f") -or ($a -eq "--files"))} {
                            $options.fileOnly = $true
                        }
                        {(($a -eq "-l") -or ($a -eq "--long"))} {
                            $options.longFormat = $true
                        }
                        {(($a -eq "-sd") -or ($a -eq "--sd") -or ($a -eq "--sort-dirs") -or ($a -eq "--group-directories-first"))} {
                            $options.dirsFirst = $true
                        }
                        {(($a -eq "-sf") -or ($a -eq "--sf") -or ($a -eq "--sort-files") -or ($a -eq "--group-files-first"))} {
                            $options.filesFirst = $true
                        }
                        {(($a -eq "-t") -or ($a -eq "--st") -or ($a -eq "-st"))} {
                            $options.sortByModificationTime = $true
                        }
                        {(($a -eq "-ds") -or ($a -eq "--ds") -or ($a -eq "-sds") -or ($a -eq "--sds") -or ($a -eq "--show-directory-size"))} {
                            $options.showDirectorySize = $true
                        }
                        default{
                            if($a -like('-*')){
                                $get_optionsResult.errorMessage = "invalid option $a"
                                $get_optionsResult.continue = $false
                                return $get_optionsResult

                            }else{
                                $get_optionsResult.errorMessage = "$a is not a valid path"
                                $get_optionsResult.continue = $false
                                return $get_optionsResult
                            }
                        }
                    }
                }
            }
        }
    }

    $get_optionsResult.options = $options
    return $get_optionsResult
}

function Get-FriendlySize {
    param($bytes)
    $sizes='B,KB,MB,GB,TB,PB,EB,ZB' -split ','
    for($i=0; ($bytes -ge 1kb) -and
        ($i -lt $sizes.Count); $i++) {$bytes/=1kb}
    $N=0; if($i -eq 0) {$N=0}
    "{0:N$($N)} {1}" -f $bytes, $sizes[$i]
}

function Get-FilesAndFoldersListing{
    Param($options, $query)
    if($options.showHiddenFiles){
        return Get-ChildItem $query -force
    }else{
        return Get-ChildItem $query
    }
}

function Get-DirectoryName{
    Param($filesAndFolders)
    
    $f = $filesAndFolders[0]

    # get the directory for the items listed
    $directoryName = $f.Parent.FullName
    if($directoryName.Length -eq 0){
        $directoryName = $f.DirectoryName
    }
    return $directoryName
}

function Get-SortedFilesAndFoldersListing{
    Param($filesAndFolders, $options)
    if($options.sortByModificationTime){
        return $filesAndFolders  | Sort-Object Lastwritetime -descending
    }elseif($options.filesFirst){
        return $filesAndFolders | Sort-Object Attributes -descending
    }elseif($options.dirsFirst){
        return $filesAndFolders
    }else{
        return $filesAndFolders  | Sort-Object Name
    }
}

function Get-ItemColor{
    Param($isFolder, $name, $fileExt)
    if($isFolder){
        $colorHex = $colorTheme.Types.Directories.WellKnown[$name]
        if($null -eq $colorHex){
            $colorHex = "EEEE8B"
        }
    }else{
        $colorHex = $colorTheme.Types.Files.WellKnown[$name]
        if($null -eq $colorHex){
            $colorHex = $colorTheme.Types.Files[$fileExt]
        }
        if($null -eq $colorHex){
            $colorHex = "EEEEEE"
        }
    }
    return ConvertFrom-RGBColor -RGB ($colorHex)
}

function Get-ItemIcon{
    Param($isFolder, $name, $fileExt)
    if($isFolder){
        $iconName = $iconTheme.Types.Directories.WellKnown[$name]
        if($null -eq $iconName){
            $iconName = $iconTheme.Types.Directories[""]
        }
    }else{
        $iconName = $iconTheme.Types.Files.WellKnown[$name]
        if($null -eq $iconName){
            $iconName = $iconTheme.Types.Files[$fileExt]
        }
        if($null -eq $iconName){
            $iconName = $iconTheme.Types.Files[""]
        }
    }
    return $glyphs[$iconName]
}

function Get-LongFormatData{
    Param($options, $filesAndFolders, $IsGitDirectory)
    if($options.longFormat){
        $acls = $filesAndFolders | get-acl -ErrorAction SilentlyContinue

        $longestOwnerAcl = ($acls | Select-Object Owner | Sort-Object { "$_".Length } -descending | Select-Object -first 1).Owner

        $longestGroupAcl = ($acls | Select-object Group | Sort-Object { "$_".Length } -descending | Select-Object -first 1).Group

        $longestDate = ($filesAndFolders | Select-Object @{n="LastWriteTime";e={$_.Lastwritetime.ToString("f")}} | Sort-Object { "$_".Length } -descending | Select-Object -first 1).LastWriteTime

        $gitIncrease = 0
        if($IsGitDirectory){
            $gitIncrease = 2
        }

        return @{
            longestOwnerAclLength = $longestOwnerAcl.Length
            longestGroupAclLength = $longestGroupAcl.Length
            longestDateLength = $longestDate.Length
            # Calculate max lengths of different long outputs so we can determine how much will fit in the console
            fullItemMaxLength = 11 + 2 + $longestOwnerAclLength + 2 + $longestGroupAclLength + 2 + 8 + 2 +  $longestDateLength + 2 + $longestItemLength + 5 + $gitIncrease
            noGroupMaxLength = 11 + 2 + $longestOwnerAclLength + 2 + 8 + 2 +  $longestDateLength + 2 + $longestItemLength + 5 + $gitIncrease
            noGroupOrOwnerMaxLength = 11 + 2 + 8 + 2 +  $longestDateLength + 2 + $longestItemLength + 5 + $gitIncrease
            noGroupOrOwnerOrModeMaxLength = 8 + 2 +  $longestDateLength + 2 + $longestItemLength + 5 + $gitIncrease
        }
    }
    return $null
}

function Get-ModeForLongListing{
    Param($modeInput)
    $mode = ""
    foreach ($m in $modeInput.ToCharArray()) {
        switch($m){
            "-" {
                $mode += (ConvertFrom-RGBColor -RGB ("EEEEEE")) + "- "
            }
            "d" {
                $mode += (ConvertFrom-RGBColor -RGB ("EEEE8B")) + $glyphs["nf-fa-folder_o"] + " "
            }
            "a" {
                $mode += (ConvertFrom-RGBColor -RGB ("EE82EE")) + $glyphs["nf-fa-archive"] + " "
            }
            "r" {
                $mode += (ConvertFrom-RGBColor -RGB ("6382FF")) + $glyphs["nf-fa-lock"] + " "
            }
            "h" {
                $mode += (ConvertFrom-RGBColor -RGB ("BABABA")) + $glyphs["nf-mdi-file_hidden"] + " "
            }
            "s" {
                $mode += (ConvertFrom-RGBColor -RGB ("EDA1A1")) + $glyphs["nf-fa-gear"] + " "
            }
            default{
                $mode += (ConvertFrom-RGBColor -RGB ("EEEEEE")) +  $m + " "
            }
        }
    }
    return $mode
}

function Get-IsGitDirectory {
    Param($directory)
    if ((Test-Path "${directory}\.git") -eq $TRUE) {
        return $TRUE
    }
    
    # Test within parent dirs
    $checkIn = (Get-Item ${directory}).parent
    while ($checkIn -ne $NULL) {
        $pathToTest = $checkIn.fullname + '/.git'
        if ((Test-Path $pathToTest) -eq $TRUE) {
            return $TRUE
        } else {
            $checkIn = $checkIn.parent
        }
    }
    
    return $FALSE
}

function PowerColorLS{
<#
 .Synopsis
  Displays a colorized directory and file listing with icons.

 .Description
  List information about files and directories (the current directory by default).
  Entries will be sorted alphabetically if no sorting option is specified.
  The directories and files will be displayed with an icon and color scheme.
  The module has a dependency on the powershell module Terminal-Icons (https://github.com/devblackops/Terminal-Icons/)
  being installed and configured first.

    Usage: PowerColorLs [OPTION]... [FILE]..."

        options:
        -a, --all           do not ignore hidden files and files starting with .
        -l, --long          use a long listing format
        -1                  list one file per line
        -d, --dirs          show only directories
        -f, --files         show only files
        -ds, -sds, --sds, --show-directory-size
                            show directory size (can take a long time)

        sorting options:

        -sd, --sort-dirs, --group-directories-first
                            sort directories first
        -sf, --sort-files, --group-files-first
                            sort files first
        -t, -st, --st
                            sort by modification time, newest first

        general options:

        -h, --help     prints help information

 .Example
   # Show help
   PowerColorLS -h

 .Example
   # Show a lising of all files and directories in the current location sorted by name
   PowerColorLS

 .Example
   # Show a lising of all files and directories in c:\test sorted by directories first
   PowerColorLS -sd c:\test

 .Example
   # Show a lising of all files and directories matching *name* in the current location sorted by files first
   PowerColorLS -sf *name*

 .Example
   # Show a lising of all files and directories in the current location, including hidden files
   PowerColorLS --all

 .Example
   # Show a lising of all files and directories in the current location, including hidden files, sorted by modification time
   PowerColorLS --all -t

 .Example
   # Show a lising of all files and directories in the current location in a long format
   PowerColorLS --long

 .Example
   # Show a lising of all files and directories in the current location in a long format including directory size
   PowerColorLS --long --show-directory-size

#>

    $get_optionsResult = Get-OptionsResult -arguments $args

    if($get_optionsResult.continue -eq $false){
        if($null -ne $get_optionsResult.errorMessage){
            $errMsg = (ConvertFrom-RGBColor -RGB ("FF0000")) + $glyphs["nf-fa-warning"] + " " + $get_optionsResult.errorMessage
            Write-Host $errMsg
        }
        return
    }

    $query = $get_optionsResult.query

    # load options
    $options = $get_optionsResult.options

    # get the items
    $filesAndFolders = Get-FilesAndFoldersListing -options $options -query $query

    if($filesAndFolders.Length -eq 0){ # nothing found
        return
    }

    # get the directory for the items listed
    $directoryName = Get-DirectoryName -filesAndFolders $filesAndFolders

    # get the current directory
    $currentPath = (Get-Location).Path

    # check if git directory
    $IsGitDirectory = Get-IsGitDirectory -directory $directoryName

    if($IsGitDirectory){
        Set-Location -Path $directoryName
        $gitStatus = git status --porcelain=v1
        $gitRoot = git rev-parse --show-toplevel
        Set-Location -Path $currentPath

        $gitStatusItems = @()

        foreach($gitStatusItem in $gitStatus){
            $gs = $gitStatusItem.Trim().Split(" ")
            $l = -join($gitRoot, "/", $gs[1])
            $gitStatusItems += @{
                status = $gs[0]
                path = $l
            }
        }        
    }

    # sorting
    $filesAndFolders = Get-SortedFilesAndFoldersListing -filesAndFolders $filesAndFolders -options $options

    # determine the longest items so we can adapt the list to the console window width
    $longestItem = $filesAndFolders | Select-Object Name, FullName | Sort-Object { "$_".Length } -descending | Select-Object -first 1
    $longestItemLength = ($longestItem).name.Length
    $longestItemIsFolder = Test-Path -path ($longestItem.FullName) -pathtype container
    if(($longestItemIsFolder) -and (-not $options.fileOnly)){
        $longestItemLength += 1
    }

    $longFormatData = Get-LongFormatData -options $options -filesAndFolders $filesAndFolders -IsGitDirectory $IsGitDirectory

	$itemSpacerWidth = 4
    $lineCharsCounter = 0

    # get how many characters we have available in this console window
    $availableCharWith = (Get-Host).ui.rawui.buffersize.width

    # start iterating over our items
	foreach ($e in $filesAndFolders) {
		$isFolder = Test-Path -path ($e.FullName) -pathtype container
		$fileExt = [System.IO.Path]::GetExtension($e.name)
		$name = $e.name
        $extra = ""

        $ignoreFile = $false

        if((-not $options.showHiddenFiles) -and ($name.StartsWith("."))) {
            $ignoreFile = $true
        }

        if(($options.dirOnly) -and (-not $isFolder)) {
            $ignoreFile = $true
        }

        if(($options.fileOnly) -and ($isFolder)) {
            $ignoreFile = $true
        }

        if(-not $ignoreFile){
            if($isFolder){
                $extra = "\"
            }

            $color = Get-ItemColor -isFolder $isFolder -name $name -fileExt $fileExt
            $icon = Get-ItemIcon -isFolder $isFolder -name $name -fileExt $fileExt
            $colorAndIcon = "${color}${icon}"
            $gitColorAndIcon = ""

            if($IsGitDirectory){
                $gitGlyph = $glyphs["nf-fa-check"]
                $gitColor = (ConvertFrom-RGBColor -RGB ("00FF00"))
                foreach($gitStatusItem in $gitStatusItems){
                    $updateGitStatus = $false
                    $currentItemForGitCompare = $e.FullName -Replace "\\", "/"
                    if($currentItemForGitCompare -eq $gitStatusItem.path){
                        $updateGitStatus = $true
                    }elseif($isFolder -and ($gitStatusItem.path.StartsWith($currentItemForGitCompare))){
                        $updateGitStatus = $true
                    }

                    if($updateGitStatus){
                        switch($gitStatusItem.status){
                            "??" {
                                $gitGlyph = $glyphs["nf-fa-question"]
                                $gitColor = (ConvertFrom-RGBColor -RGB ("FF0000"))
                            }
                            default{
                                $gitGlyph = $gitStatusItem.status
                                $gitColor = (ConvertFrom-RGBColor -RGB ("FFFF00"))
                            }
                        }                        
                    }
                }
                $gitColorAndIcon = "${gitColor}${gitGlyph} "
                $colorAndIcon = "${gitColorAndIcon}${colorAndIcon}"
            }

            $nameOutput = "${name}${extra}"

            if($options.longFormat){
                $acl = Get-Acl $e.FullName
                $lw = ($e.LastWriteTime).ToString("f")
                $owner = $acl.Owner
                $group = $acl.Group
                if($isFolder){
                    if($options.showDirectorySize){
                        $directorySizeInBytes = ((Get-Childitem $e.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Sum Length -ErrorAction SilentlyContinue | Select-Object sum).sum)
                        $size = Get-FriendlySize -bytes $directorySizeInBytes
                    }else{
                        $size = ""
                    }
                }else{
                    $size = Get-FriendlySize -bytes $e.Length
                }
                $sizeWithSpace = $size.PadRight(8)

                $mode = Get-ModeForLongListing $e.Mode

                $ownerWithSpace = "${owner}" + (" "*($longFormatData.longestOwnerAclLength - $owner.length))
                $groupWithSpace = "${group}" + (" "*($longFormatData.longestGroupAclLength - $group.length))
                $lwWithSpace = "${lw}" + (" "*($longFormatData.longestDateLength - $lw.Length))

                $ownerColor = (ConvertFrom-RGBColor -RGB ("FDFFBA"))
                $groupColor = (ConvertFrom-RGBColor -RGB ("D3D865"))
                $lwColor = (ConvertFrom-RGBColor -RGB ("45B2A1"))
                $sizeColor = (ConvertFrom-RGBColor -RGB ("FDFFBA"))

                if($availableCharWith -gt $longFormatData.fullItemMaxLength){
                    $printout = "${mode}  ${ownerColor}${ownerWithSpace}  ${groupColor}${groupWithSpace}  ${sizeColor}${sizeWithSpace}  ${lwColor}${lwWithSpace}  ${colorAndIcon} ${nameOutput}"
                }elseif($availableCharWith -gt $longFormatData.noGroupMaxLength){
                    $printout = "${mode}  ${ownerColor}${ownerWithSpace}  ${sizeColor}${sizeWithSpace}  ${lwColor}${lwWithSpace}  ${colorAndIcon} ${nameOutput}"
                }elseif($availableCharWith -gt $longFormatData.noGroupOrOwnerMaxLength){
                    $printout = "${mode}  ${sizeColor}${sizeWithSpace}  ${lwColor}${lwWithSpace}  ${colorAndIcon} ${nameOutput}"
                }elseif($availableCharWith -gt $longFormatData.noGroupOrOwnerOrModeMaxLength){
                    $printout = "${sizeColor}${sizeWithSpace}  ${lwColor}${lwWithSpace}  ${colorAndIcon} ${nameOutput}"
                }else{
                    $printout = "${sizeColor}${sizeWithSpace}  ${colorAndIcon} ${nameOutput}"
                }
            }else{
                $printout = "${icon} ${nameOutput}" + (" "*($longestItemLength - $nameOutput.length + $itemSpacerWidth))
                $lineCharsCounter += $printout.length
                if($IsGitDirectory){
                    $lineCharsCounter += 2
                }
            }

            if ((-not $options.oneEntryPerLine) -and(-not $options.longFormat) -and ( $lineCharsCounter -ge ($availableCharWith)) ) {
                Write-Host ""
                $lineCharsCounter = $printout.length
                if($IsGitDirectory){
                    $lineCharsCounter += 2
                }
            }

            if($options.longFormat){
                Write-Host "${printout}"
            }elseif($options.oneEntryPerLine){
                Write-Host "${gitColorAndIcon}${color}${printout}"
            }else{
                Write-Host "${gitColorAndIcon}${color}${printout}" -nonewline
            }
        }
	}
}

Export-ModuleMember -Function PowerColorLs

