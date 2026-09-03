#Requires -Version 7.2

BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $repoRoot 'src\Tree.Compare\Tree.Compare.psd1') -Force
}

Describe 'ConvertTo-TcRelativeKey' {
    It 'normalizes separators and case' {
        $root = Join-Path $TestDrive 'Root'
        New-Item -ItemType Directory -Path $root | Out-Null
        $full = Join-Path $root 'Sub\File.TXT'
        ConvertTo-TcRelativeKey -Root $root -FullPath $full |
            Should -Be 'sub/file.txt'
    }
}

Describe 'Test-TcIsIgnoredPath' {
    It 'matches DriverPackage junk leaf' {
        Test-TcIsIgnoredPath -RelPath 'a/Thumbs.db' -Patterns (Get-TcIgnorePatterns -CompareProfile DriverPackage) |
            Should -BeTrue
    }

    It 'matches __MACOSX segment' {
        Test-TcIsIgnoredPath -RelPath '__macosx/foo.txt' -Patterns (Get-TcIgnorePatterns -Profile DriverPackage) |
            Should -BeTrue
    }

    It 'does not match payload inf' {
        Test-TcIsIgnoredPath -RelPath 'net/oem.inf' -Patterns (Get-TcIgnorePatterns -Profile DriverPackage) |
            Should -BeFalse
    }
}

Describe 'Compare-TcTree' {
    It 'returns Identical in Speed without hashing when metadata matches' {
        $a = Join-Path $TestDrive 'ident-a'
        $b = Join-Path $TestDrive 'ident-b'
        New-Item -ItemType Directory -Path (Join-Path $a 'n') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $b 'n') | Out-Null
        'same' | Set-Content -LiteralPath (Join-Path $a 'n\x.bin') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $a 'n\x.bin') -Destination (Join-Path $b 'n\x.bin')
        $stamp = [datetime]::UtcNow.AddDays(-2)
        (Get-Item -LiteralPath (Join-Path $a 'n\x.bin')).LastWriteTimeUtc = $stamp
        (Get-Item -LiteralPath (Join-Path $b 'n\x.bin')).LastWriteTimeUtc = $stamp

        $r = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Quiet
        $r.Verdict | Should -Be 'Identical'
        $r.ContentEqual | Should -BeTrue
        $r.HashedCount | Should -Be 0
        (Get-TcCompareExitCode -Result $r) | Should -Be 0
    }

    It 'Speed TimestampSuspect when bytes match but mtime differs; Accuracy Identical' {
        $a = Join-Path $TestDrive 'ts-a'
        $b = Join-Path $TestDrive 'ts-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'payload' | Set-Content -LiteralPath (Join-Path $a 'drv.sys') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $a 'drv.sys') -Destination (Join-Path $b 'drv.sys')
        (Get-Item -LiteralPath (Join-Path $b 'drv.sys')).LastWriteTimeUtc =
            (Get-Item -LiteralPath (Join-Path $a 'drv.sys')).LastWriteTimeUtc.AddHours(3)

        $speed = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Quiet
        $speed.Verdict | Should -Be 'TimestampSuspect'
        $speed.TimestampOnly | Should -BeTrue
        $speed.ContentEqual | Should -BeFalse
        $speed.HashedCount | Should -Be 0
        (Get-TcCompareExitCode -Result $speed) | Should -Be 1

        $acc = Compare-TcTree -PathA $a -PathB $b -Mode Accuracy -Quiet
        $acc.Verdict | Should -Be 'Identical'
        $acc.ContentEqual | Should -BeTrue
        $acc.HashedCount | Should -Be 2
        $acc.TimestampMismatchCount | Should -Be 0
    }

    It 'reports length mismatch as Different without hashing' {
        $a = Join-Path $TestDrive 'len-a'
        $b = Join-Path $TestDrive 'len-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'aa' | Set-Content -LiteralPath (Join-Path $a 'f.txt') -NoNewline
        'aaaa' | Set-Content -LiteralPath (Join-Path $b 'f.txt') -NoNewline

        $r = Compare-TcTree -PathA $a -PathB $b -Mode Accuracy -Quiet
        $r.Verdict | Should -Be 'Different'
        $r.LengthMismatchCount | Should -Be 1
        $r.HashedCount | Should -Be 0
        (Get-TcCompareExitCode -Result $r) | Should -Be 2
    }

    It 'reports left-only and right-only paths' {
        $a = Join-Path $TestDrive 'path-a'
        $b = Join-Path $TestDrive 'path-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'x' | Set-Content -LiteralPath (Join-Path $a 'onlyA.txt')
        'y' | Set-Content -LiteralPath (Join-Path $b 'onlyB.txt')

        $r = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Quiet
        $r.Verdict | Should -Be 'Different'
        $r.LeftOnlyCount | Should -Be 1
        $r.RightOnlyCount | Should -Be 1
    }

    It 'DriverPackage ignores Thumbs.db via -Profile alias' {
        $a = Join-Path $TestDrive 'drv-a'
        $b = Join-Path $TestDrive 'drv-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'inf' | Set-Content -LiteralPath (Join-Path $a 'oem.inf')
        Copy-Item (Join-Path $a 'oem.inf') (Join-Path $b 'oem.inf')
        $stamp = [datetime]::UtcNow
        (Get-Item (Join-Path $a 'oem.inf')).LastWriteTimeUtc = $stamp
        (Get-Item (Join-Path $b 'oem.inf')).LastWriteTimeUtc = $stamp
        'junk' | Set-Content -LiteralPath (Join-Path $a 'Thumbs.db')

        $r = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Profile DriverPackage -Quiet
        $r.Verdict | Should -Be 'Identical'
        $r.Profile | Should -Be 'DriverPackage'
        $r.LeftOnlyCount | Should -Be 0
    }

    It 'AlignChildRoots compares inner folders with different wrapper names' {
        $a = Join-Path $TestDrive 'wrap-a\Rel_R1'
        $b = Join-Path $TestDrive 'wrap-b\Rel_R2'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'sys' | Set-Content -LiteralPath (Join-Path $a 'x.sys')
        Copy-Item (Join-Path $a 'x.sys') (Join-Path $b 'x.sys')
        $stamp = [datetime]::UtcNow
        (Get-Item (Join-Path $a 'x.sys')).LastWriteTimeUtc = $stamp
        (Get-Item (Join-Path $b 'x.sys')).LastWriteTimeUtc = $stamp

        $r = Compare-TcTree -PathA (Join-Path $TestDrive 'wrap-a') -PathB (Join-Path $TestDrive 'wrap-b') `
            -Mode Speed -AlignChildRoots -Quiet
        $r.Verdict | Should -Be 'Identical'
    }

    It 'Accuracy detects hash mismatch at equal length' {
        $a = Join-Path $TestDrive 'hash-a'
        $b = Join-Path $TestDrive 'hash-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'abcd' | Set-Content -LiteralPath (Join-Path $a 'f.bin') -NoNewline
        'abce' | Set-Content -LiteralPath (Join-Path $b 'f.bin') -NoNewline
        $stamp = [datetime]::UtcNow
        (Get-Item (Join-Path $a 'f.bin')).LastWriteTimeUtc = $stamp
        (Get-Item (Join-Path $b 'f.bin')).LastWriteTimeUtc = $stamp

        $r = Compare-TcTree -PathA $a -PathB $b -Mode Accuracy -Quiet
        $r.Verdict | Should -Be 'Different'
        $r.HashMismatchCount | Should -Be 1
        $r.LengthMismatchCount | Should -Be 0
    }

    It 'Robocopy Speed is Identical when metadata matches' {
        $a = Join-Path $TestDrive 'rc-ident-a'
        $b = Join-Path $TestDrive 'rc-ident-b'
        New-Item -ItemType Directory -Path (Join-Path $a 'n') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $b 'n') | Out-Null
        'same' | Set-Content -LiteralPath (Join-Path $a 'n\x.bin') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $a 'n\x.bin') -Destination (Join-Path $b 'n\x.bin')
        $stamp = [datetime]::UtcNow.AddDays(-2)
        (Get-Item -LiteralPath (Join-Path $a 'n\x.bin')).LastWriteTimeUtc = $stamp
        (Get-Item -LiteralPath (Join-Path $b 'n\x.bin')).LastWriteTimeUtc = $stamp

        $r = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Engine Robocopy -Quiet
        $r.Verdict | Should -Be 'Identical'
        $r.Engine | Should -Be 'Robocopy'
        $r.HashedCount | Should -Be 0
        (Get-TcCompareExitCode -Result $r) | Should -Be 0
    }

    It 'Robocopy Speed TimestampSuspect maps Older/Newer/Tweaked; Accuracy engine is rejected' {
        $a = Join-Path $TestDrive 'rc-ts-a'
        $b = Join-Path $TestDrive 'rc-ts-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'payload' | Set-Content -LiteralPath (Join-Path $a 'drv.sys') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $a 'drv.sys') -Destination (Join-Path $b 'drv.sys')
        (Get-Item -LiteralPath (Join-Path $b 'drv.sys')).LastWriteTimeUtc =
            (Get-Item -LiteralPath (Join-Path $a 'drv.sys')).LastWriteTimeUtc.AddHours(3)

        $speed = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Engine Robocopy -Quiet
        $speed.Verdict | Should -Be 'TimestampSuspect'
        $speed.TimestampOnly | Should -BeTrue
        $speed.HashedCount | Should -Be 0
        (Get-TcCompareExitCode -Result $speed) | Should -Be 1

        $acc = Compare-TcTree -PathA $a -PathB $b -Mode Accuracy -Engine Robocopy -Quiet
        $acc.Verdict | Should -Be 'Error'
        $acc.Error | Should -Match 'Hybrid|Native'
        (Get-TcCompareExitCode -Result $acc) | Should -Be 3
    }

    It 'Hybrid Speed is timestamp-suspect then Hybrid Accuracy hashes Identical' {
        $a = Join-Path $TestDrive 'hy-a'
        $b = Join-Path $TestDrive 'hy-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'payload' | Set-Content -LiteralPath (Join-Path $a 'drv.sys') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $a 'drv.sys') -Destination (Join-Path $b 'drv.sys')
        (Get-Item -LiteralPath (Join-Path $b 'drv.sys')).LastWriteTimeUtc =
            (Get-Item -LiteralPath (Join-Path $a 'drv.sys')).LastWriteTimeUtc.AddHours(3)

        $speed = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Engine Hybrid -Quiet
        $speed.Verdict | Should -Be 'TimestampSuspect'
        $speed.Engine | Should -Be 'Hybrid'

        $acc = Compare-TcTree -PathA $a -PathB $b -Mode Accuracy -Engine Hybrid -Quiet
        $acc.Verdict | Should -Be 'Identical'
        $acc.ContentEqual | Should -BeTrue
        $acc.HashedCount | Should -Be 2
        $acc.TimestampMismatchCount | Should -Be 0
    }

    It 'Robocopy Speed maps Extra/New to path-only and Changed to length' {
        $a = Join-Path $TestDrive 'rc-path-a'
        $b = Join-Path $TestDrive 'rc-path-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'x' | Set-Content -LiteralPath (Join-Path $a 'onlyA.txt')
        'y' | Set-Content -LiteralPath (Join-Path $b 'onlyB.txt')
        'aa' | Set-Content -LiteralPath (Join-Path $a 'len.txt') -NoNewline
        'aaaa' | Set-Content -LiteralPath (Join-Path $b 'len.txt') -NoNewline

        $r = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Engine Robocopy -Quiet
        $r.Verdict | Should -Be 'Different'
        $r.LeftOnlyCount | Should -BeGreaterThan 0
        $r.RightOnlyCount | Should -BeGreaterThan 0
        $r.LengthMismatchCount | Should -Be 1
        $r.HashedCount | Should -Be 0
    }

    It 'Robocopy Speed /FFT absorbs a 1-second gap (FAT 2-second granularity)' {
        $a = Join-Path $TestDrive 'rc-fft-a'
        $b = Join-Path $TestDrive 'rc-fft-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        'fat' | Set-Content -LiteralPath (Join-Path $a 'f.bin') -NoNewline
        Copy-Item -LiteralPath (Join-Path $a 'f.bin') -Destination (Join-Path $b 'f.bin')
        $stamp = [datetime]::UtcNow.AddDays(-1)
        (Get-Item -LiteralPath (Join-Path $a 'f.bin')).LastWriteTimeUtc = $stamp
        (Get-Item -LiteralPath (Join-Path $b 'f.bin')).LastWriteTimeUtc = $stamp.AddSeconds(1)

        $native = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Engine Native -Quiet
        $native.Verdict | Should -Be 'TimestampSuspect'

        $robo = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Engine Robocopy -Quiet
        $robo.Verdict | Should -Be 'Identical'
        $robo.TimestampMismatchCount | Should -Be 0
    }
}

Describe 'ConvertFrom-TcRobocopyLog' {
    It 'maps Extra/New/Changed/Older and tracks directory context' {
        $fixture = Join-Path $PSScriptRoot '..\fixtures\robocopy-unilog-sample.txt'
        $lines = Get-Content -LiteralPath $fixture
        $parsed = ConvertFrom-TcRobocopyLog -Lines $lines -SourceRoot 'C:\tc\left' -DestRoot 'C:\tc\right'

        $parsed.LeftOnly | Should -Contain 'left.txt'
        $parsed.LeftOnly | Should -Contain 'onlya'
        $parsed.LeftOnly | Should -Contain 'onlya/newnested.txt'
        $parsed.RightOnly | Should -Contain 'right.txt'
        $parsed.RightOnly | Should -Contain 'onlyb'
        $parsed.RightOnly | Should -Contain 'sub/extra-in-sub.txt'
        $parsed.LengthMismatch | Should -Contain 'len.txt'
        $parsed.TimestampMismatch | Should -Contain 'tweak.txt'
        $parsed.Same | Should -Contain 'sub/same.txt'
    }
}

Describe 'Format-TcAgentSummary' {
    It 'starts with TC-COMPARE-OK for Identical' {
        $a = Join-Path $TestDrive 'sum-a'
        $b = Join-Path $TestDrive 'sum-b'
        New-Item -ItemType Directory -Path $a, $b | Out-Null
        $r = Compare-TcTree -PathA $a -PathB $b -Mode Speed -Quiet
        (Format-TcAgentSummary -Result $r) | Should -Match '^TC-COMPARE-OK verdict=Identical'
    }
}
