@{
    Extensions = @{
        ChatGPT = @{
            Id               = 'hehggadaopoacecdllhhajmbjkdcmajg'
            UpdateUrl        = 'https://clients2.google.com/service/update2/crx'
            InstallationMode = 'force_installed'
        }
    }

    Browser = @{
        BrowserSignin               = 1
        SyncDisabled                = 0
        PasswordManagerEnabled      = 1
        AutofillAddressEnabled      = 1
        AutofillCreditCardEnabled   = 0
        DeveloperToolsAvailability  = 0
        DefaultPopupsSetting        = 2
        DefaultNotificationsSetting = 2
        BackgroundModeEnabled       = $false
        MetricsReportingEnabled     = $false
    }

    # Documentation for ChatGPT's user-approved site access. These are not
    # written as Chrome policy because Chrome has no equivalent consent policy.
    AllowedOrigins = @(
        'http://localhost:*'
        'http://127.0.0.1:*'
        'https://chatgpt.com'
        'https://*.chatgpt.com'
        'https://openai.com'
        'https://*.openai.com'
    )
}
