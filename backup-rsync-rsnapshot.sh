#!/bin/bash

#############################################
#set config variables

#backup root dir
sBACKUP_ROOT="/external/backup/"

#source dir;target dir
aSOURCE="
/dsdata/File Server/./;file-server/
/dsdata/mail/./;mail/
"

#rsync extra args/opt
sOPT="--no-o --no-g"

#exclude old backups ?
bEXCLUDE_OLD=0
#max backups per type
#keeps only 30 latest daily backups
nMAX_DAILY="30"
#keeps only 5 latest weekly backups
nMAX_WEEKLY="5"
#keeps only 12 latest monthly backups
nMAX_MONTHLY="12"
#keeps only 5 latest yearly backups
nMAX_YEARLY="5"

#############################################
#parse arguments

export LC_ALL=pt_BR.UTF-8
export LANG=pt_BR.UTF-8
export LANGUAGE=pt_BR:pt:en

set -o errexit -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null 

if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
	echo 'I’m sorry, `getopt --test` failed in this environment.'
	exit 1
fi

LONGOPTS=date:,type:,verbose,dry-run,help
OPTIONS=d:t:vnh

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
	exit 2
fi

eval set -- "$PARSED"

pTODAY=""
pTYPE=""
verbose=0
dryrun=0
#dryrun=1

# now enjoy the options in order and nicely split until we see --
while true; do
	case "$1" in
		-d|--date) pTODAY="$2"
		shift 2
		;;
		-t|--type) pTYPE="$2"
		shift 2
		;;
		-v|--verbose) verbose=1
		shift
		;;
		-n|--dry-run) dryrun=1
		shift
		;;
		-h|--help) 
			echo "Use: $0 without arguments: TODAY is NOW and TYPE is daily
-d YYYY-MM-DD: generate backup dir as YYYY-MM-DD-dow-daily (p.ex. -d 2021-12-23 => 2021-12-23-thu-daily)
-t type_of_backup: generate backup dir as YYYY-MM-DD-dow-type (p.ex. -t weekly => YYYY-MM-DD-dow-weekly)
where type_of_backup: daily (default), weekly, monthly, yearly

EXAMPLE: $0 -d 2021-12-23 -t yearly => 2021-12-23-thu-yearly"
		exit
		;;
		--)
		shift
		break
		;;
		*) echo "Error in arguments"
		exit 3
		;;
	esac
done
if [ ! -z ${pTODAY} ]; then
	if [ "${#pTODAY}" -ne 10 ]; then
		echo "TODAY invalid date error: ${pTODAY} (use YYYY-MM-DD)"
		exit 2
	fi
	re='[^0-9-]'
	if [[ ${pTODAY} =~ $re ]]; then
		echo "TODAY invalid date error: ${pTODAY} (use YYYY-MM-DD)"
		exit 2
	fi
	! sTMP=`date -d ${pTODAY} >/dev/null 2>&1`
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		echo "TODAY invalid date error: ${pTODAY} (use YYYY-MM-DD)"
		exit 2
	fi

	echo TODAY as: ${pTODAY}
fi

if [ ! -z ${pTYPE} ]; then
	case "${pTYPE}" in
		diario|semanal|mensal|anual)
		;;
		*) echo "TYPE invalid: ${pTYPE} must be: (diario|semanal|mensal|anual) or none (-t not used, default diario)"
		exit 2
		;;
	esac
	echo TYPE as: ${pTYPE}
fi

#############################################
#calc dates

dTODAY=`date +%Y-%m-%d`
if [ ! -z "${pTODAY}" ]; then
	dTODAY=${pTODAY};
fi

dDAY_OF_MONTH=`date +%d -d ${dTODAY}`
dWEEK_DAY=`date +%u -d ${dTODAY}`
dMONTH=`date +%m -d ${dTODAY}`

aABREV="seg,ter,qua,qui,sex,sab,dom"
aEXTENSO="segunda,terca,quarta,quinta,sexta,sabado,domingo"

sABREV=`echo ${aABREV} | cut -d',' -f${dWEEK_DAY}`
sEXTENSO=`echo ${aEXTENSO} | cut -d',' -f${dWEEK_DAY}`

#dDAY=`date +%Y%m%d-%a | iconv -f UTF-8 -t ascii//TRANSLIT | tr [:upper:] [:lower:]`
#dDATE=`date "+%d/%m/%Y - %R (%A)" | iconv -f UTF-8 -t ascii//TRANSLIT | tr [:upper:] [:lower:]`
dDAY=`date +%Y-%m-%d-${sABREV} -d ${dTODAY} | tr [:upper:] [:lower:]`
dDATE=`date "+%d/%m/%Y - %R (${sEXTENSO})" -d ${dTODAY} | tr [:upper:] [:lower:]`

#############################################
#set backup type, source link-dest and create target dir

sTYPE="diario"
if [ "${dDAY_OF_MONTH}" = "01" ]; then
	if [ "${dMONTH}" = "01" ]; then
		sTYPE="anual"
	else
		sTYPE="mensal"
	fi
elif [ "${dWEEK_DAY}" = "7" ]; then
	sTYPE="semanal"
fi

if [ ! -z "${pTYPE}" ]; then
	sTYPE=${pTYPE};
fi

sCURRENT="${dDAY}-${sTYPE}"

if [ ! -d "${sBACKUP_ROOT}" ]; then
	echo "Dir ${sBACKUP_ROOT} not found"
	exit 1
fi

if [ ! -d "${sBACKUP_ROOT}${sCURRENT}" ]; then
	if [ ${dryrun} -eq 1 ]; then
		echo "mkdir ${sBACKUP_ROOT}${sCURRENT}"
	fi
	if [ ${dryrun} -eq 0 ]; then
		mkdir "${sBACKUP_ROOT}${sCURRENT}"
	fi
fi

#############################################
#execute backup / rsync

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
for i in ${aSOURCE}; do
	sSOURCE=`echo ${i} | cut -f1 -d';'`
	sTARGET=`echo ${i} | cut -f2 -d';'`
	sNAME=`echo "${sTARGET}" | tr -cd '[:alpha:]'`

	sLINK_DEST=""
	sPREVIUS=`ls -1r ${sBACKUP_ROOT} | grep -v ${sCURRENT} | head -n 1`
	if [ ! -z "${sPREVIUS}" ]; then
		if [ "${sPREVIUS}" != "${sCURRENT}" ]; then
			sLINK_DEST="--link-dest=${sBACKUP_ROOT}${sPREVIUS}/${sTARGET}"
		fi
	fi

	sLOG="/root/log/${sCURRENT}-${sNAME}.log"
	sERR="/root/err/${sCURRENT}-${sNAME}-err.log"
	sCMD="rsync -av --stats --delete --numeric-ids --relative --delete-excluded ${sOPT} ${sLINK_DEST} ${sSOURCE} ${sBACKUP_ROOT}${sCURRENT}/${sTARGET}"
	if [ ${dryrun} -eq 1 ]; then
		echo "${sCMD} ${sLOG} ${sERR}"
	fi
	if [ ${dryrun} -eq 0 ]; then
		${sCMD} >${sLOG} 2>${sERR}
	fi
done
IFS=$SAVEIFS

#############################################
#exclude old backups

if [ ${dryrun} -eq 0 ]; then
if [ ${bEXCLUDE_OLD} -eq 1 ]; then

	nDAILY=`ls -1d ${sBACKUP_ROOT}*diario 2>/dev/null | wc -l`
	nEXCLUDE_DAILY=$((${nDAILY} - ${nMAX_DAILY}))
	if [ "${nEXCLUDE_DAILY}" -gt 0 ]; then
		echo "Delete ${nEXCLUDE_DAILY} daily"
		ls -1d ${sBACKUP_ROOT}*diario | head -n ${nEXCLUDE_DAILY} | xargs -I{} rm -rf "{}"
	fi

	nWEEKLY=`ls -1d ${sBACKUP_ROOT}*semanal 2>/dev/null | wc -l`
	nEXCLUDE_WEEKLY=$((${nWEEKLY} - ${nMAX_WEEKLY}))
	if [ "${nEXCLUDE_WEEKLY}" -gt 0 ]; then
		echo "Deleted ${nEXCLUDE_WEEKLY} weekly"
		ls -1d ${sBACKUP_ROOT}*semanal | head -n ${nEXCLUDE_WEEKLY} | xargs -I{} rm -rf "{}"
	fi

	nMONTHLY=`ls -1d ${sBACKUP_ROOT}*mensal 2>/dev/null | wc -l`
	nEXCLUDE_MONTHLY=$((${nMONTHLY} - ${nMAX_MONTHLY}))
	if [ "${nEXCLUDE_MONTHLY}" -gt 0 ]; then
		echo "Deleted ${nEXCLUDE_MONTHLY} monthly"
		ls -1d ${sBACKUP_ROOT}*mensal | head -n ${nEXCLUDE_MONTHLY} | xargs -I{} rm -rf "{}"
	fi

	nYEARLY=`ls -1d ${sBACKUP_ROOT}*anual 2>/dev/null | wc -l`
	nEXCLUDE_YEARLY=$((${nYEARLY} - ${nMAX_YEARLY}))
	if [ "${nEXCLUDE_YEARLY}" -gt 0 ]; then
		echo "Deleted ${nEXCLUDE_YEARLY} yearly"
		ls -1d ${sBACKUP_ROOT}*anual | head -n ${nEXCLUDE_YEARLY} | xargs -I{} rm -rf "{}"
	fi

fi
fi
