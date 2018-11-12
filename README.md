# sendmail2mailgun
Bash script handling sendmail input to send mails over Mailgun's HTTP API

# Configuration
`sendmail2mailgun`'s configuration options are:
- Mailgun API account settings: domain + key
- Log filepath
- Mailing defaults: sender, recipient(s), subject

There are no runtime parameters for the Mailgun account settings for security reasons (visibility of the key in the logs); 
they have to be retrieved from a file. 

To be able to adapt these configurations easily in case `sendmail2mailgun` is used in different contexts and/or with
several Mailgun API accounts, the main aka global configuration may be extended with:
- Mailgun API account configurations
- usecase configurations

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

