Function Cleanup($o) { if (($o -ne $null) -and ($o.GetType().GetMethod("Dispose") -ne $null)) { $o.Dispose() } }

Function Decode-Base64File($src, $dst) {
  Try {
    $in = (Get-Item $src).OpenRead()
    $b64 = New-Object -TypeName System.Security.Cryptography.FromBase64Transform
    $m = [System.Security.Cryptography.CryptoStreamMode]::Read
    $d = New-Object -TypeName System.Security.Cryptography.CryptoStream $in,$b64,$m
    Copy-Stream $d ($out = [System.IO.File]::OpenWrite($dst))
  } Finally { Cleanup $in; Cleanup $out; Cleanup $d }
}

Function Copy-Stream($src, $dst) { $b = New-Object Byte[] 4096; while (($i = $src.Read($b, 0, $b.Length)) -ne 0) { $dst.Write($b, 0, $i) } }

Function Check-Files($h) {
  return $h.GetEnumerator() | ForEach-Object {
    $dst = Unresolve-Path $_.Key
    New-Object psobject -Property @{
      chk_exists = ($exists = Test-Path $dst -PathType Leaf)
      src_md5 = ($sMd5 = $_.Value)
      dst_md5 = ($dMd5 = if ($exists) { Get-MD5Sum $dst } else { $null })
      chk_dirty = ($dirty = if ($sMd5 -ne $dMd5) { $true } else { $false })
      verifies = if ($dirty -eq $false) { $true } else { $false }
    }
  } | Select-Object -Property chk_exists,src_md5,dst_md5,chk_dirty,verifies
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

Function Unresolve-Path($p) { if ($p -eq $null) { return $null } else { return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) } }

Check-Files (Invoke-Input $hash_file) | ConvertTo-Csv -NoTypeInformation
