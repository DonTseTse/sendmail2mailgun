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

# Configuration
`sendmail2mailgun`'s configuration options are:
- Mailgun API account settings: domain + key
- Log filepath
- Mailing defaults: sender, recipient(s), subject

`sendmail2mailgun` is able to work in two different modes for greatest flexibility:
- the "configuration file less" - called runtime - mode: the only file used is the keyfile for the Mailgun API. The flags 
  `--domain <domain> --keyfile <filepath>` are compulsory
- the normal mode, with a global configuration file and possible further ramifications

The default mode can be selected at installation time and it can be overwritten at runtime using the `--cfg` flag:
- if it's in runtime mode, `--cfg <filepath>` makes it switch to normal mode
- if it's in normal mode, `--cfg ""` makes it switch it to runtime mode, `--cfg <filepath>` overwrites the filepath used by default

## File-based configuration
In normal mode, `sendmail2mailgun` loads the global configuration file (`--cfg` flag overwrites default location). To be able to adapt 
the file-based configuration easily to different contexts and/or several Mailgun API accounts, the global configuration may be extended 
with **usecase configurations**. These replicate and overwrite the global configuration and add a usecase name which can be useful in 
log analytics. Likewise, in case several Mailgun API accounts are (re)used accross the different configuration files, these may stored 
in dedicated files and addressed by name.

These different configuration files are described here, templates may be found here.

### Usecase configurations
A usecase configuration file may either be specified by `--uc- <filpath>` or using the flag `-uc <name>` if 
`usecase_configurations_folder` is defined in the global configuration file.  

Variable definitions:
- `name`: if a single global log is used, useful to be able to track in the logs with which configuration a mail was sent
- `log_filepath`
- `default_sender`, `default_recipient`, `default_subject`
- `mailgun_api_account_name`
 
### Mailgun API account configurations
- *Mailgun account configurations* in `mailgun_api_account_configurations_folder`

# Logging
`sendmail2mailgun` provides fully configurable logging capabilities. It's able to handle stdout and classic file logging, each with 
their own logging level.
By default, the `stdout_logging_level` is set to 0 (disabled), the `logging_level` to 1. Whether file logging occurs depend if
`log_filepath` is set.

# Parametrization
send2mail2mailgun has a range of essential internal parameters:
- `mail_uses_html_body`: defaults to 0/false for a text body. Enable with the flag `-html`
- `stdout_log_level`: defaults to 0/disabled. Enable with the flag `-v`
- `log_filepath`: can be set through many ways, in the order of precendence
	+ `--log-filepath <filepath>` flag
	+ in the usecase configuration
	+ in the global configuration
- `log_level`: defaults to 1 (normal logging)

# Installer
TODO 
By default, installs global configurtion to `/etc/sendmail2mailgun/main.conf`
