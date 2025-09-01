param (
	[Parameter(Mandatory=$true)]
	[string]$sendto,
	[string]$subj,
	[string]$msgfile,
	[string]$drfiles
)

$body = Get-Content $msgfile -Raw
$from = "catalog-backup@primary.demo.veritas.com"
$drarray = $drfiles.Split(',')
$smtpsrv = "tus3hub-relay.community.veritas.com"

Send-MailMessage -Subject $subj -SmtpServer $smtpsrv -From $from -To $sendto -Attachments $drarray -Body $body