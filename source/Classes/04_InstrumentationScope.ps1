class InstrumentationScope
{
    [string] $Name
    [string] $Version
    [string] $SchemaUrl
    hidden [hashtable] $_attributes

    # Constructor with name only
    InstrumentationScope([string]$Name)
    {
        if ([string]::IsNullOrWhiteSpace($Name))
        {
            throw [System.ArgumentException]::new('InstrumentationScope name cannot be null or empty.')
        }

        $this.Name        = $Name
        $this.Version     = ''
        $this.SchemaUrl   = ''
        $this._attributes = @{}
    }

    # Constructor with name and version
    InstrumentationScope([string]$Name, [string]$Version)
    {
        if ([string]::IsNullOrWhiteSpace($Name))
        {
            throw [System.ArgumentException]::new('InstrumentationScope name cannot be null or empty.')
        }

        $this.Name        = $Name
        $this.Version     = if ($null -ne $Version) { $Version } else { '' }
        $this.SchemaUrl   = ''
        $this._attributes = @{}
    }

    # Constructor with name, version, and schema URL
    InstrumentationScope([string]$Name, [string]$Version, [string]$SchemaUrl)
    {
        if ([string]::IsNullOrWhiteSpace($Name))
        {
            throw [System.ArgumentException]::new('InstrumentationScope name cannot be null or empty.')
        }

        $this.Name        = $Name
        $this.Version     = if ($null -ne $Version) { $Version } else { '' }
        $this.SchemaUrl   = if ($null -ne $SchemaUrl) { $SchemaUrl } else { '' }
        $this._attributes = @{}
    }

    # Sets or overwrites a scope attribute
    [void] SetAttribute([string]$Key, [object]$Value)
    {
        if ([string]::IsNullOrWhiteSpace($Key))
        {
            throw [System.ArgumentException]::new('Attribute key cannot be null or empty.')
        }

        $this._attributes[$Key] = $Value
    }

    # Returns the value of a scope attribute, or $null if not present
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

    # Serializes the scope to an OTLP-compliant hashtable
    [hashtable] ToOtlp()
    {
        $attrs = [System.Collections.Generic.List[hashtable]]::new()

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

            $attrs.Add(@{ key = $key; value = $otlpValue })
        }

        return @{
            name                   = $this.Name
            version                = $this.Version
            schemaUrl              = $this.SchemaUrl
            attributes             = $attrs.ToArray()
            droppedAttributesCount = 0
        }
    }
}
