. (join-path $PSScriptRoot "/json 1.7.ps1")

function Create-Gist { 
<# 
	.Synopsis
	Publishes Github Gists.

	.Description
	Publishes files as Owned or Anonymous Github Gists.

	.Parameter InputObject
	Accepts a series of files which will be published as a single Gist

	.Parameter File
	A single file path to be published as a Gist.

	.Parameter Description 
	(optional) The Description of this Gist.

	.Parameter Username	
	(optional) The Username of the Github account which will own this Gist.

	.Example
	gist -File "Hello.js" -Description "Hello.js greets all visitors"
	Publish an anonymous single file Gist

	.Example
	gist -File "Hello.js" -Description "Hello.js greets all visitors" -Username katniss
	Publish an anonymous single file Gist
#>
	Param(
		[Parameter(Position=0, ValueFromPipeline=$true)]
		[PSObject]$InputObject = $null,
		[string]$File = $null,
		[string]$Description = "",
		[string]$Username = ""
	)
	BEGIN {
		$files = @{}
	}
	PROCESS {
		if( $InputObject -ne $null -and $InputObject.GetType() -eq [System.IO.FileInfo] ) {
			$fileinfo = [System.IO.FileInfo]$InputObject
		}
		elseif( Test-Path $File ){
			$fileinfo = Get-Item $File
		}
		else {
			return
		}

		$path = $fileinfo.FullName
		$filename = $fileinfo.Name

		$content = [IO.File]::readalltext($path)

		$content = $content -replace "\\", "\\\\"
		$content = $content -replace "`t", "\t"
		$content = $content -replace "`r", "\r"
		$content = $content -replace "`n", "\n"
		$content = $content -replace """", "\"""
		$content = $content -replace "/", "\/"
		$content = $content -replace "'", "\'"

		$files.Add($filename, $content)
	}
	END {

		$apiurl = "https://api.github.com/gists"

		$request = [Net.WebRequest]::Create($apiurl)

		if($Username.length -gt 0) {
			$password = read-host "Password" -AsSecureString

			$basicpwd= [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
			$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($basicpwd)

			$creds = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([String]::Format("{0}:{1}", $username, $password)))
			$request.Headers.Add("Authorization", "Basic " + $creds)
		}

		$request.ContentType = "application/json"
		$request.Method = "POST"

		$files.GetEnumerator() | % { 
			$singlefilejson = """" + $_.Name + """: {
					""content"": """ + $_.Value + """
			},"
	
			$filesjson += $singlefilejson
		}

		$filesjson = $filesjson.TrimEnd(',')
		
		$body = "{
			""description"": """ + $Description + """,
			""public"": true,
			""files"": {" + $filesjson + "}
		}"

		$bytes = [text.encoding]::Default.getbytes($body)
		$request.ContentLength = $bytes.Length

		$stream = [io.stream]$request.GetRequestStream()
		$stream.Write($bytes,0,$bytes.Length)

		$response = $request.GetResponse()

			
		
		$responseStream = $response.GetResponseStream()
		$reader = New-Object system.io.streamreader -ArgumentList $responseStream
		$content = $reader.ReadToEnd()
		$reader.close()

		if( $response.StatusCode -ne [Net.HttpStatusCode]::Created ) {
			$content | write-error
		}

		$result = convertfrom-json $content -Type PSObject -ForceType

		$url = $result.html_url
	
		write-output $url
	}
}

new-alias gist Create-Gist

export-modulemember -alias gist -function Create-Gist
