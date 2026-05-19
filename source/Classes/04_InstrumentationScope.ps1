class InstrumentationScope {
    [string] $Name
    [string] $Version
    [string] $SchemaUrl
    hidden [System.Collections.Generic.Dictionary[string, string]] $_attributes

    InstrumentationScope([string]$Name, [string]$Version) {
        $this._Init($Name, $Version, '')
    }

    InstrumentationScope([string]$Name, [string]$Version, [string]$SchemaUrl) {
        $this._Init($Name, $Version, $SchemaUrl)
    }

    hidden [void] _Init([string]$Name, [string]$Version, [string]$SchemaUrl) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw [System.ArgumentException]::new('Name cannot be null or empty.')
        }
        $this.Name        = $Name
        $this.Version     = $Version
        $this.SchemaUrl   = $SchemaUrl
        $this._attributes = [System.Collections.Generic.Dictionary[string, string]]::new()
    }

    [void] SetAttribute([string]$Key, [string]$Value) {
        $this._attributes[$Key] = $Value
    }

    [hashtable] ToOtlp() {
        $dict = [ordered]@{
            name    = $this.Name
            version = $this.Version
        }
        if (-not [string]::IsNullOrEmpty($this.SchemaUrl)) {
            $dict['schemaUrl'] = $this.SchemaUrl
        }
        if ($this._attributes.Count -gt 0) {
            $attrs = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($kv in $this._attributes.GetEnumerator()) {
                $attrs.Add(@{ key = $kv.Key; value = @{ stringValue = $kv.Value } })
            }
            $dict['attributes'] = $attrs.ToArray()
        }
        return $dict
    }
}
