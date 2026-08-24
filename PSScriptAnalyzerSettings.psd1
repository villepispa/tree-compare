@{
    # Product lint settings for Tree.Compare (scripts/ + src/).
    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseBOMForUnicodeEncodedFile'
    )
}
