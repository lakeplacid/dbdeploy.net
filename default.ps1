$framework = '4.0'Properties {    $root_dir = Split-Path $psake.build_script_file	    $build_artifacts_dir = "$root_dir\build\"    $package_dir = "$root_dir\package"    $code_dir = "source"    $solution = "src\dbdeploy.net.sln"    #$api_key = Get-Content "api.key"    $configuration = "Debug"    $scripts_dir = "$root_dir\scripts"}Task Build {    Exec { msbuild $solution }}Task Clean {    Exec { msbuild "$solution" /t:Clean /p:Configuration=$configuration /v:quiet "/p:OutDir=$build_artifacts_dir\" }        if (Test-Path $build_artifacts_dir){        Remove-Item $build_artifacts_dir -recurse    }    if (Test-Path $package_dir){        Remove-Item $package_dir -recurse    }}Task BuildPackage -depends Clean -description "Builds a package on 'build' "  {    if (-not (Test-Path $build_artifacts_dir)){        mkdir $build_artifacts_dir    }            if (-not (Test-Path $package_dir)){        mkdir $package_dir    }            $version, $commits, $hash = $(git describe --tags --long) -split "-"    $version = $version -replace "v","" # remove the v because the correct format for assemblies does not include include    $hash = $hash.Substring(1) # the hash starts with g, for git, remove it    $date_tag = $(get-date -Uformat "%Y%m%d_%H%M")        $version_cs_content = @"// Do not commit the changes to this file.using System.Reflection;[assembly: AssemblyVersionAttribute("$version")][assembly: AssemblyInformationalVersionAttribute("$version-$commits-$hash-$date_tag")][assembly: AssemblyFileVersionAttribute("$version")]"@    $version_cs_content | set-content .\src\SolutionVersionAssemblyInfo.cs    Write-Host "Building" -ForegroundColor Green    Exec { msbuild "$solution" /t:Build /p:Configuration=$configuration /v:quiet "/p:OutDir=$build_artifacts_dir" }    foreach($filename in @('Net.Sf.Dbdeploy.ilmerge.dll', 'dbdeploy.ilmerge.exe', 'dbdeploy.NAnt.ilmerge.dll','dbdeploy.Powershell.ilmerge.dll','msbuild.dbdeploy.task.ilmerge.dll')){        $original = $filename.Replace(".ilmerge.",".")        Move-Item $build_artifacts_dir\$original  $build_artifacts_dir\$filename     }    tools\ilmerge.exe /v4 /lib:$build_artifacts_dir /target:library /out:$build_artifacts_dir\Net.Sf.Dbdeploy.dll Net.Sf.Dbdeploy.ilmerge.dll nvelocity.dll /internalize:internalize_exclusions.txt    tools\ilmerge.exe /v4 /lib:$build_artifacts_dir /target:exe /out:$build_artifacts_dir\dbdeploy.exe dbdeploy.ilmerge.exe Net.Sf.Dbdeploy.dll  NDesk.Options.dll /internalize:internalize_exclusions.txt    tools\ilmerge.exe /v4 /lib:$build_artifacts_dir /target:library /out:$build_artifacts_dir\dbdeploy.NAnt.dll dbdeploy.NAnt.ilmerge.dll NAnt.Core.dll Net.Sf.Dbdeploy.dll /internalize:internalize_exclusions.txt    tools\ilmerge.exe /v4 /lib:$build_artifacts_dir /target:library /out:$build_artifacts_dir\dbdeploy.Powershell.dll dbdeploy.Powershell.ilmerge.dll Net.Sf.Dbdeploy.dll /internalize:internalize_exclusions.txt    tools\ilmerge.exe /v4 /lib:$build_artifacts_dir /target:library /out:$build_artifacts_dir\msbuild.dbdeploy.task.dll msbuild.dbdeploy.task.ilmerge.dll Net.Sf.Dbdeploy.dll /internalize:internalize_exclusions.txt    mkdir $build_artifacts_dir\console    mkdir $build_artifacts_dir\powershell    mkdir $build_artifacts_dir\nant    mkdir $build_artifacts_dir\msbuild    mkdir $build_artifacts_dir\lib    mkdir $build_artifacts_dir\scripts    Copy-Item -Path $build_artifacts_dir\dbdeploy.exe -Destination $build_artifacts_dir\console    Copy-Item -Path $build_artifacts_dir\dbdeploy.Powershell.dll -Destination $build_artifacts_dir\powershell    Copy-Item -Path $build_artifacts_dir\dbdeploy.NAnt.dll -Destination $build_artifacts_dir\nant    Copy-Item -Path $build_artifacts_dir\msbuild.dbdeploy.task.dll -Destination $build_artifacts_dir\msbuild    Copy-Item -Path $build_artifacts_dir\Net.Sf.Dbdeploy.dll -Destination $build_artifacts_dir\lib        Copy-Item -Path $scripts_dir\*.sql -Destination $build_artifacts_dir\scripts        Get-ChildItem build -Exclude console,msbuild,nant,powershell,scripts,lib  |Remove-Item -recurse        Write-Host "Creating packages" -ForegroundColor Green    Get-ChildItem $build_artifacts_dir\ -recurse | Write-Zip -IncludeEmptyDirectories -EntryPathRoot "build" -OutputPath $package_dir\dbdeploy.net-$version.zip    Write-Host "Package created at $package_dir\dbdeploy.net-$version.zip" -ForegroundColor Green}Task Help {    Write-Documentation}Task default -depends Help