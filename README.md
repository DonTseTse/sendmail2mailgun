# Introduction
`sendmail2mailgun` is a bash script that is able to handle sendmail input to send mails over Mailgun's HTTP API. It can be a useful 
alternative if the usual mailing infrastructure is not available or desirable. 

The sendmail format encodes the mail variables as `<key>:<value>` headers, with everything else beeing the mail body: 
```
From: <The Sender>sender@example.com
To: receiver@example.com
Subject: This is a mail
This is the mail body.
```  
`sendmail2mailgun` expects it as piped input:
```
printf "From: ...\nTo: ...\nSubject:...\nMail body" | sendmail2mailgun
```
In order to work, `sendmail2mailgun` needs the Mailgun API account settings (domain + key). For security reasons the key can't 
be provided as runtime parameter (visibility in the logs), it has to be provided through a file. 

# Logging
`sendmail2mailgun` provides fully configurable logging capabilities. It's able to handle stdout and classic file logging, each with 
their own logging level.
By default, the `stdout_logging_level` is set to 0 (disabled), the `logging_level` to 1. Whether file logging occurs depend if
`log_filepath` is set. 

# Configuration
To summarize, `sendmail2mailgun`'s configuration options are:
- Mailgun API account settings: domain + key
- Log filepath
- Mailing defaults: sender, recipient(s), subject

`sendmail2mailgun` is able to work in two different modes for greatest flexibility:
- the "configuration file less" mode: in this mode, the flags `--domain <domain> --keyfile <filepath>` are compulsory
- the normal mode, with a global configuration file and possible further ramifications
The default mode can be selected at installation time and it can be overwritten at runtime using the `--cfg` flag:
- if it's in "configuration file less" mode, `--cfg <filepath>` makes it switch to normal mode
- if it's in normal mode, `--cfg ""` makes it switch it to "configuration file less" mode, `--cfg <filepath>` overwrites the
  configuration file used by default

To be able to adapt these configurations easily in case `sendmail2mailgun` is used in different contexts and/or with
several Mailgun API accounts, the main aka global configuration may be extended with:
- Mailgun API account configurations
- usecase configurations: flags `-uc <usecase name>`

## Configuration file description

Templates may be found in [configuration_templates]

### Global
The following variable definitions are taken into account in this type of file: 
- `mailgun_domain` and `mailgun_api_key`
- `log_filepath`
- `default_sender`, `default_recipient`, `default_subject`
- `mailgun_api_account_configurations_folder`
- `usecase_configurations_folder`

### Mailgun API account
The following variable definitions are taken into account in this type of file: 
- `domain`
- `key`

### Usecase
The following variable definitions are taken into account in this type of file: 
- `name`
- `mailgun_api_account_name`
- `log_filepath`
- `default_sender`, `default_recipient`, `default_subject`

# Logging
`sendmail2mailgun` provides fully configurable logging capabilities. It's able to handle stdout and classic file logging, each with 
their own logging level.
By default, the `stdout_logging_level` is set to 0 (disabled), the `logging_level` to 1. Whether file logging occurs depend if
`log_filepath` is set.

----------------------------




# Garbage
- *Mailgun account configurations* in `mailgun_api_account_configurations_folder`
- *usecase configurations*  in `usecase_configurations_folder`

still possible to use a copy of the configuration mentioned above for each usecase

If `sendmail2mailgun` is used in several usecases it's desirable to be able to have dedicated configuration for each.
While it's possible to use a copy of the configuration mentioned above for each usecase, sendmail2mailgun also provides
a logic separation 

To be able to use sendmail2mailgun in many different contexts it supports *usecase configurations* 
A usecase configuration
supports the variable definitions:
- `name`: if a single global log is used, useful to be able to track in the logs with which configuration a mail was sent
- `log_filepath`
- `default_sender`, `default_recipient`, `default_subject`
- `mailgun_api_account_name`

`sendmail2mailgun` searches for a file at a location set during installation
(default `/etc/sendmail2mailgun/main.conf`), this path may be overwritten at runtime using the flag `--cfg <filepath>`.
## File configuration structure


## Minimal configuration

# Parametrization
send2mail2mailgun has a range of essential internal parameters:
- `mail_uses_html_body`: defaults to 0/false for a text body. Enable with the flag `-html`
- `stdout_log_level`: defaults to 0/disabled. Enable with the flag `-v`
- `log_filepath`: can be set through many ways, in the order of precendence
	+ `--log-filepath <filepath>` flag
	+ in the usecase configuration
	+ in the global configuration
- `log_level`: defaults to 1 (normal logging)

# Logging

