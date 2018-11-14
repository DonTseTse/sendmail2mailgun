#! /bin/bash

### Configuration
legitimate_recipient="test@whatever.com"
domain=""
keyfile=""


### Testing variables
# Mail 1: sendmail format, all fields
mail[0]="From:sender@example.com\nTo:$legitimate_recipient\nSubject:Mail subject\nMail body"
# Mail 2: sender 0 | recipient 1 | subject 1
mail[1]="To:$legitimate_recipient\nSubject:Mail subject\nMail body"
# Mail 3: sender 1 | recipient 0 | subject 1
mail[2]="From:sender@example.com\nSubject:Mail subject\nMail body"
# Mail 4: sender 1 | recipient 1 | subject 0
mail[3]="From:sender@example.com\nTo:$legitimate_recipient\nMail body"
# Mail 5: sender 1 | recipient 0 | subject 0
mail[4]="From:sender@example.com\nMail body"
# Mail 6: sender 0 | recipient 1 | subject 0
mail[5]="To:$legitimate_recipient\nMail body"
# Mail 7: sender 0 | recipient 0 | subject 1
mail[6]="Subject:Mail subject\nMail body"
# Mail 8: no fields, only body
mail[7]="Mail body"
# TODO test formatting errors, multine body, malformed emails, several recipients

flags[0]="--cfg $configuration_filepath"
flags[0]="--domain $domain"
flags[0]="--html"
flags[0]="--keyfile $keyfile"
flags[0]="--log-filepath $log_filepath"
flags[0]="--log-level $log_level"
flags[0]="--mg-cfg $mailgun_api_account_configuration_filepath"
flags[0]="--uc-cfg $usecase_configuration_filepath"
flags[0]="--usecase $usecase"
flags[0]="-v"
flags[0]="--vv"



printf "${mail[0]}" | bash emulator.sh -v
