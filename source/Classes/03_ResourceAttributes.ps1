class ResourceAttributes
{
    hidden [hashtable] $_attributes

    # Default constructor: auto-populates host, OS, PID, and runtime attributes
    ResourceAttributes()
    {
        $this._attributes = @{}
        $this.PopulateDefaults()
    }

    # Constructor with service name
    ResourceAttributes([string]$ServiceName)
    {
        $this._attributes = @{}
        $this._attributes['service.name'] = $ServiceName
        $this.PopulateDefaults()
    }

    hidden [void] PopulateDefaults()
    {
        if (-not $this._attributes.ContainsKey('host.name'))
        {
            $this._attributes['host.name'] = [System.Net.Dns]::GetHostName()
        }

        $this._attributes['os.type']                 = [ResourceAttributes]::DetectOsType()
        $this._attributes['process.pid']             = [System.Diagnostics.Process]::GetCurrentProcess().Id
        $this._attributes['process.runtime.name']    = 'PowerShell'
        $this._attributes['process.runtime.version'] = $PSVersionTable.PSVersion.ToString()
    }

    # Sets or overwrites an attribute
    [void] SetAttribute([string]$Key, [object]$Value)
    {
        if ([string]::IsNullOrWhiteSpace($Key))
        {
            throw [System.ArgumentException]::new('Attribute key cannot be null or empty.')
        }

        $this._attributes[$Key] = $Value
    }

    # Returns the value of an attribute, or $null if not present
    [object] GetAttribute([string]$Key)
    {
        if ($this._attributes.ContainsKey($Key))
        {
            return $this._attributes[$Key]
        }

        return $null
    }

    # Returns true if the attribute key exists
    [bool] HasAttribute([string]$Key)
    {
        return $this._attributes.ContainsKey($Key)
    }

    # Removes an attribute; does nothing if the key does not exist
    [void] RemoveAttribute([string]$Key)
    {
        $this._attributes.Remove($Key)
    }

    # Returns all attribute keys
    [string[]] GetKeys()
    {
        return @($this._attributes.Keys)
    }

    # Serializes attributes to the OTLP key-value array format
    [object[]] ToOtlpAttributes()
    {
        $result = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($key in $this._attributes.Keys)
        {
            $val = $this._attributes[$key]

            $otlpValue = switch ($val.GetType().Name)
            {
                'Int32'   { @{ intValue    = [long]$val } }
                'Int64'   { @{ intValue    = $val } }
                'Double'  { @{ doubleValue = $val } }
                'Boolean' { @{ boolValue   = $val } }
                default   { @{ stringValue = $val.ToString() } }
            }

            $result.Add(@{ key = $key; value = $otlpValue })
        }

        return $result.ToArray()
    }

    # Detects the OTel os.type value for the current platform
    static [string] DetectOsType()
    {
        $isWindows = Get-Variable -Name 'IsWindows' -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $isWindows)
        {
            $isMacOS = Get-Variable -Name 'IsMacOS' -ValueOnly -ErrorAction SilentlyContinue
            $isLinux = Get-Variable -Name 'IsLinux' -ValueOnly -ErrorAction SilentlyContinue

            if ($isWindows) { return 'windows' }
            if ($isMacOS)   { return 'darwin' }
            if ($isLinux)   { return 'linux' }
        }

        return 'windows'
    }
}
