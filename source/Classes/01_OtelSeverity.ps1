class OtelSeverity {
    static [int] $TRACE = 1
    static [int] $DEBUG = 5
    static [int] $INFO  = 9
    static [int] $WARN  = 13
    static [int] $ERROR = 17
    static [int] $FATAL = 21

    static [string] GetText([int]$SeverityNumber) {
        switch ($SeverityNumber) {
            { $_ -ge 1  -and $_ -le 4  } { return 'TRACE' }
            { $_ -ge 5  -and $_ -le 8  } { return 'DEBUG' }
            { $_ -ge 9  -and $_ -le 12 } { return 'INFO'  }
            { $_ -ge 13 -and $_ -le 16 } { return 'WARN'  }
            { $_ -ge 17 -and $_ -le 20 } { return 'ERROR' }
            { $_ -ge 21 -and $_ -le 24 } { return 'FATAL' }
            default                       { return 'UNSPECIFIED' }
        }
    }

    static [bool] IsValid([int]$SeverityNumber) {
        return ($SeverityNumber -ge 1 -and $SeverityNumber -le 24)
    }
}
