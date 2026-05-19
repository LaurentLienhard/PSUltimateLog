class ResourceAttributes {
    hidden [System.Collections.Generic.Dictionary[string, object]] $_attributes

    ResourceAttributes([string]$ServiceName) {
        $this._attributes = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this._Populate($ServiceName)
    }

    hidden [void] _Populate([string]$ServiceName) {
        $this._attributes['service.name']            = $ServiceName
        $this._attributes['host.name']               = [System.Net.Dns]::GetHostName()
        $this._attributes['os.type']                 = [System.Environment]::OSVersion.Platform.ToString().ToLower()
        $this._attributes['process.pid']             = [System.Diagnostics.Process]::GetCurrentProcess().Id
        $this._attributes['process.runtime.name']    = 'PowerShell'
        $this._attributes['process.runtime.version'] = $PSVersionTable.PSVersion.ToString()
    }

    [bool] HasAttribute([string]$Key) {
        return $this._attributes.ContainsKey($Key)
    }

    [object] GetAttribute([string]$Key) {
        if (-not $this._attributes.ContainsKey($Key)) { return $null }
        return $this._attributes[$Key]
    }

    [void] SetAttribute([string]$Key, [object]$Value) {
        $this._attributes[$Key] = $Value
    }

    [hashtable[]] ToOtlpAttributes() {
        $result = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($kv in $this._attributes.GetEnumerator()) {
            $value = if ($kv.Value -is [int] -or $kv.Value -is [long]) {
                @{ intValue = $kv.Value }
            } else {
                @{ stringValue = $kv.Value.ToString() }
            }
            $result.Add(@{ key = $kv.Key; value = $value })
        }
        return $result.ToArray()
    }
}
