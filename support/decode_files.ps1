Function Cleanup($o) { if (($o -ne $null) -and ($o.GetType().GetMethod("Dispose") -ne $null)) { $o.Dispose() } }

Function Decode-Base64File($src, $dst) {
  Try {
    $in = (Get-Item $src).OpenRead()
    $b64 = New-Object -TypeName System.Security.Cryptography.FromBase64Transform
    $m = [System.Security.Cryptography.CryptoStreamMode]::Read
    $d = New-Object -TypeName System.Security.Cryptography.CryptoStream $in,$b64,$m
    echo $null > $dst
    Copy-Stream $d ($out = [System.IO.File]::OpenWrite($dst))
  } Finally { Cleanup $in; Cleanup $out; Cleanup $d }
}

Function Copy-Stream($src, $dst) { $b = New-Object Byte[] 4096; while (($i = $src.Read($b, 0, $b.Length)) -ne 0) { $dst.Write($b, 0, $i) } }

Function Decode-Files($hash) {
  $hash.GetEnumerator() | ForEach-Object {
    $tmp = Unresolve-Path $_.Key
    $sMd5 = (Get-Item $tmp).BaseName.Replace("b64-", "")
    $tzip, $dst = (Unresolve-Path $_.Value["tmpzip"]), (Unresolve-Path $_.Value["dst"])
    $decoded = if ($tzip -ne $null) { $tzip } else { $dst }
    Decode-Base64File $tmp $decoded
    Remove-Item $tmp -Force
    $dMd5 = Get-MD5Sum $decoded
    $verifies = if ($sMd5 -eq $dMd5) { $true } else { $false }
    if ($tzip) { Unzip-File $tzip $dst; Remove-Item $tzip -Force }
    New-Object psobject -Property @{ dst = $dst; verifies = $verifies; src_md5 = $sMd5; dst_md5 = $dMd5; tmpfile = $tmp; tmpzip = $tzip }
  } | Select-Object -Property dst,verifies,src_md5,dst_md5,tmpfile,tmpzip
}

Function Get-MD5Sum($src) {
  Try {
    $c = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $bytes = $c.ComputeHash(($in = (Get-Item $src).OpenRead()))
    return ([System.BitConverter]::ToString($bytes)).Replace("-", "").ToLower()
  } Finally { Cleanup $c; Cleanup $in }
}

Function Invoke-Input($in) {
  $in = Unresolve-Path $in
  Decode-Base64File $in ($decoded = "$($in).ps1")
  $expr = Get-Content $decoded | Out-String
  Remove-Item $in,$decoded -Force
  return Invoke-Expression "$expr"
}

Function Release-COM($o) { if ($o -ne $null) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($o) } }

Function Unresolve-Path($p) { if ($p -eq $null) { return $null } else { return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) } }

Function Unzip-File($src, $dst) {
  $r = "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4"
  if (($PSVersionTable.PSVersion.Major -ge 3) -and ((gp "$r\Full").Version -like "4.5*" -or (gp "$r\Client").Version -like "4.5*")) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null; [System.IO.Compression.ZipFile]::ExtractToDirectory("$src", "$dst")
  } else {
    Try { $s = New-Object -ComObject Shell.Application; ($dp = $s.NameSpace($dst)).CopyHere(($z = $s.NameSpace($src)).Items(), 0x610) } Finally { Release-Com $s; Release-Com $z; Release-COM $dp }
  }
}

Decode-Files (Invoke-Input $hash_file) | ConvertTo-Csv -NoTypeInformation
