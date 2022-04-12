Backup script rsync in rsnapshot style, but using timestamps as dir names (daily.0 => 2022-04-11-mon-daily)

O problema:

O rsnapshot é uma otima ferramenta de backup, que utiliza o rsync - mas para um usuario que for resgatar um arquivo, o formato dos diretorios (diario.0, diario.1, semana.3, mes.2, etc) confunde bastante.

Uma alternativa é o script rsnapshot-timestamps:

    https://github.com/kmccormick/rsnapshot-timestamp

Mas ele faz uso do modo "sync" do rsnapshot - por isso nao o utilizo.

Este script foi inspirado no rsnapshot, mas nao usa o rsnapshot.

Peguei os comandos que o rsnapshot gera para backups comuns, e criei um script que atendesse minha necessidade, com diretorios em formato YYYY-MM-DD-dow-type, onde:

     - YYYY-MM-DD: é o ano, mes e dia
     - dow: é o dia da semana (seg, ter, qua...)
     - type: é o tipo de backup (diario, semanal, mensal, anual)

     Um exemplo de saida é: 2022-03-12-sat-diario

Como usar:

ATENCAO:
- O script tem alguns pontos hardcode usando os nomes de tipo de backup (pt-BR: diario, semanal, mensal, anual) - se precisar usar em ingles, verifique estes pontos
- A parte de exclusao de diretorios antigos foi testada, mas nao exaustivamente, entao cabe usar com cuidado

1) Edite o script e modifique os parametros  base:

     sBACKUP_ROOT="/root-dir/"
     aSOURCE="/source-dir/./;target-dir/"

     A variavel "aSOURCE" pode ter diversos diretorios, cada grupo em uma linha

     aSOURCE="/source-dir/./;target-dir/
     /source-dir-2/./;target-dir-2/
     /source-dir-3/./;target-dir-3/
     /source-dir-4/./;target-dir-4/"

     Modifique tambem as variaveis sLOG e sERR (linha 200), ajustando o diretorio onde deve gerar os logs do rsync executado.

2) Execute o script

     chmod +x backup-rsync-rsnapshot.sh
     ./backup-rsync-rsnapshot.sh

3) Coloque na cron se desejado

     00 01 * * * /root/backup-rsync-rsnapshot.sh

Alem disso, o script pode ser executado com a data do backup e o tipo do mesmo como parametros - o objetivo é poder gerar um nome de diretorio personalizado se necessario:

   ./backup-rsync-rsnapshot.sh -d 2022-03-15 -t anual

    Ira gerar um diretorio 2022-03-15-ter-anual

Tem tambem a opcao "--dry-run/-n" para apenas mostrar os comandos que seram executados.

Por fim, tem a variavel "bEXCLUDE_OLD", que se setada para "1" tenta excluir os diretorios mais antigos, conforme as quantidades maximas:

    nMAX_DAILY=30, maximo de 30 diretorios diarios
    nMAX_WEEKLY=5, maximo de 5 diretorios semanais
    nMAX_MONTHLY=12, maximo de 12 diretorios mensais
    nMAX_YEARLY=5, maximo de 5 diretorios anuais
    
==============

The problem:

rsnapshot is a great backup tool, which uses rsync - but for a user who is going to rescue a copy, the format of the directories (diary.0, diary.1, week.3, month.2, etc) is quite confusing. .

An alternative is the rsnapshot-timestamps script:

    https://github.com/kmccormick/rsnapshot-timestamp

But it makes use of rsnapshot's "sync" mode - so I don't use it.

This script was inspired by rsnapshot, but does not use rsnapshot.

I took the commands that rsnapshot generates for common backups, and created a script that met my need, with directories in YYYY-MM-DD-dow-type format, where:

     - YYYY-MM-DD: is the year, month and day
     - dow: is the day of the week (Mon, Tue, Wed...)
     - type: is the type of backup (daily, weekly, monthly, yearly)

     An example output is: 2022-03-12-sat-daily

How to use:

ATTENTION:
- The script has some hardcode points using the backup type names (pt-BR: diario-daily, semanal-weekly, mensal-monthly, anual-yearly) - if you need to use it in english, check these points.
- The part of deleting old directories has been tested, but not exhaustively, so please use with care

1) Edit the script and modify the base parameters:

     sBACKUP_ROOT="/root-dir/"
     aSOURCE="/source-dir/./;target-dir/"

     The variable "aSOURCE" can have several directories (one group per line):

     aSOURCE="/source-dir/./;target-dir/
     /source-dir-2/./;target-dir-2/
     /source-dir-3/./;target-dir-3/
     /source-dir-4/./;target-dir-4/"

     Also modify the sLOG and sERR variables (line 200), adjusting the directory where the logs of the executed rsync should be generated.

2) Run the script

     chmod +x backup-rsync-rsnapshot.sh
     ./backup-rsync-rsnapshot.sh

3) Put in cron if you want

     00 01 * * * /root/backup-rsync-rsnapshot.sh

Furthermore, the script can be run with the backup date and backup type as parameters - the goal is to be able to generate a custom directory name if necessary:

   ./backup-rsync-rsnapshot.sh -d 2022-03-15 -t anual

    Will generate a directory 2022-03-15-ter-anual

It also has the option "--dry-run/n" to just show the commands that will be executed.

Finally, there is the variable "bEXCLUDE_OLD", which if set to "1" tries to exclude the oldest directories, according to the maximum amounts:

    nMAX_DAILY=30, maximum of 30 daily directories
    nMAX_WEEKLY=5, maximum of 5 weekly directories
    nMAX_MONTHLY=12, maximum of 12 monthly directories
    nMAX_YEARLY=5, maximum of 5 yearly directories
