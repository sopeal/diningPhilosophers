	#!/bin/bash
# uruchom.sh - skrypt uruchamiający filozofow

function komunikat_skrypt() {
    echo "$(date +"%d/%m %T.%N") PID:$$ $1"
}
function komunikat() {
    echo "$(date +"%d/%m %T.%N") PID:$BASHPID FID $1 $2"
}
function komunikat_proba(){
    komunikat $1 "Probuje zalozyc blokade wylaczna na WID $2"
}
function chwyc_widelce() {
    komunikat_proba $1 $2 && flock -x $3 && komunikat $1 "Zalozylem blokade wylaczna na WID $2"
    komunikat_proba $1 $4 && flock -x $5 && komunikat $1 "Zalozylem blokade wylaczna na WID $4"
}
function konsumuj() {
    local CZAS=$2
    if [ "$CZAS" = "losowy" ] ; then CZAS=0.$RANDOM; fi;
    komunikat $1 "Bede konsumowal posilek nr $3 przez nastepne ${CZAS}s."
    sleep $CZAS
    komunikat $1 "Skonczylem konsumowac posilek nr $3."
}
function odloz_widelce() {
    flock -u $3 && komunikat $1 "Zdjalem blokade wylaczna WID $2 ."
    flock -u $5 && komunikat $1 "Zdjalem blokade wylaczna WID $4 ."
}
function rozmyslaj(){
    local CZAS=$2
    if [ "$CZAS" = "losowy" ] ; then local readonly CZAS=0.$RANDOM; fi;
    komunikat $1 "Bede rozmyslal przez nastepne ${CZAS}s, ostatni posilek $3."
    sleep $CZAS
    komunikat $1 "Skonczylem rozmyslac."
}
function sprawdz_blad() {
    if [ $? != 0 ] ; then
	    exit 666
	fi
}
function filozof() {
local readonly _FID=$1
local readonly _KATALOG_STOLU=$2
local readonly _LICZBA_POSILKOW=$3
local readonly _CZAS_KONSUMOWANIA=$4
local readonly _CZAS_ROZMYSLANIA=$5
local readonly _LICZBA_FILOZOFOW=$6
local readonly _POTOK_DO_WYSYLANIA=$7
local readonly _POTOK_DO_ODBIERANIA=$8
local _PIERWSZY_WID=-1
local _DRUGI_WID=-1

if [[ 0 == $(( _FID % 2 )) ]] ; then
    _PIERWSZY_WID=$_FID
    _DRUGI_WID=$(( $(( _FID % _LICZBA_FILOZOFOW )) +1 ))

else
    _PIERWSZY_WID=$(( $(( _FID % _LICZBA_FILOZOFOW )) +1 ))
    _DRUGI_WID=$_FID
fi

exec 7>${_KATALOG_STOLU}/$_PIERWSZY_WID
exec 9>${_KATALOG_STOLU}/$_DRUGI_WID

_PIERWSZEGO_DESKRYPTOR=7
_DRUGIEGO_DESKRYPTOR=9

for _JEDZONY_POSILEK in $(seq $_LICZBA_POSILKOW) ; do
    komunikat $_FID "^^^START^^^ KATALOG_STOLU $_KATALOG_STOLU LICZBA_POSILKOW $_LICZBA_POSILKOW\
 CZAS KONSUMOWANIA $_CZAS_KONSUMOWANIA CZAS_ROZMYSLANIA $_CZAS_ROZMYSLANIA LICZBA_FILOZOFOW $_LICZBA_FILOZOFOW \
PIERWSZY POTOK $_POTOK_DO_WYSYLANIA DRUGI POTOK $_POTOK_DO_ODBIERANIA PIERWSZY POBIERANY WIDELEC $(realpath ${_KATALOG_STOLU}/$_PIERWSZY_WID)"

    chwyc_widelce $_FID $_PIERWSZY_WID $_PIERWSZEGO_DESKRYPTOR $_DRUGI_WID $_DRUGIEGO_DESKRYPTOR
    konsumuj $_FID $_CZAS_KONSUMOWANIA $_JEDZONY_POSILEK
    odloz_widelce $_FID $_PIERWSZY_WID $_PIERWSZEGO_DESKRYPTOR $_DRUGI_WID $_DRUGIEGO_DESKRYPTOR
    rozmyslaj $_FID $_CZAS_ROZMYSLANIA $_JEDZONY_POSILEK

    if [[ _JEDZONY_POSILEK -eq $(( _LICZBA_POSILKOW - _LICZBA_POSILKOW/2 )) ]] ; then
        komunikat $_FID "---POLOWA--- OSTATNI ZJEDZONY POSILEK $_JEDZONY_POSILEK"
        echo "kontynuuj" >> $_POTOK_DO_WYSYLANIA
        cat $_POTOK_DO_ODBIERANIA >> /dev/null
    fi
done

komunikat $_FID "___STOP___ZJEDZONE POSILKI $LICZBA_POSILKOW."
}

while	 getopts f:s:n:k:r: OPCJA
do
    case $OPCJA in
        f) declare -i LICZBA_FILOZOFOW=$OPTARG;;
        n) declare -i LICZBA_POSILKOW=$OPTARG;;
        k) CZAS_KONSUMOWANIA=$OPTARG;;
        r) CZAS_ROZMYSLANIA=$OPTARG;;
        s) KATALOG_STOLU=$OPTARG;;
        *) echo Nieznana opcja $OPTARG; exit 2;;
    esac
done

if test ${LICZBA_FILOZOFOW:-0} -le 1; then LICZBA_FILOZOFOW=5	; fi;
if test ${LICZBA_POSILKOW:-0} -le 1; then LICZBA_POSILKOW=7; fi;
if test ${CZAS_KONSUMOWANIA:-0} -eq 0; then CZAS_KONSUMOWANIA=losowy; fi;
if test ${CZAS_ROZMYSLANIA:-0} -eq 0; then CZAS_ROZMYSLANIA=losowy; fi;
KATALOG_STOLU=${KATALOG_STOLU:-stolik}

komunikat_skrypt "uruchom.sh: liczba filozofow $LICZBA_FILOZOFOW, liczba posilkow $LICZBA_POSILKOW, \
katalog stolu $KATALOG_STOLU, czas konsumowania $CZAS_KONSUMOWANIA s, czas rozmyslania $CZAS_ROZMYSLANIA s."


if ! test -d $KATALOG_STOLU ; then mkdir $KATALOG_STOLU ; fi ;
if ! test -d ${KATALOG_STOLU} ; then mkdir ${KATALOG_STOLU} ; fi ;

#tworzenie widelcow
for nr_widelca in $(seq 1 ${LICZBA_FILOZOFOW}); do
    touch ${KATALOG_STOLU}/$nr_widelca
    sprawdz_blad
done

readonly prefix_pierwszy_potok=${KATALOG_STOLU}"/pierwszy_potok_filozofa_nr_"
readonly prefix_drugi_potok=${KATALOG_STOLU}"/drugi_potok_filozofa_nr_"

# Utworzenie potokow dla filozofow
# Nie mozna wykorzystac jednego potoku, poniewaz jednokrotna operacja odczytu moze odczytac wszystkie komunikaty z kolejki
for nr_filozofa in $(seq 1 ${LICZBA_FILOZOFOW}); do
	pierszy_potok_filozofa=${prefix_pierwszy_potok}${nr_filozofa}
    rm -f $pierszy_potok_filozofa
    mkfifo $pierszy_potok_filozofa
	sprawdz_blad
	drugi_potok_filozofa=${prefix_drugi_potok}$nr_filozofa
    rm -f $drugi_potok_filozofa
    mkfifo $drugi_potok_filozofa
	sprawdz_blad
done

for NR_FILOZOFA in $(shuf --input-range=1-$LICZBA_FILOZOFOW) ; do
    komunikat_skrypt "$(hostname): STARTUJE FILOZOF NR $NR_FILOZOFA, LICZBA POSILKOW $LICZBA_POSILKOW, KATALOG STOLU $KATALOG_STOLU ,\
CZAS KONSUMOWANIA ${CZAS_KONSUMOWANIA}s, CZAS ROZMYSLANIA ${CZAS_ROZMYSLANIA}s, LICZBA_FILOZOFOW $LICZBA_FILOZOFOW , \
SCIEZKA DO PIERWSZEGO POTOKU ${prefix_pierwszy_potok}${NR_FILOZOFA}, SCIEZKA DO DRUGIEGO POTOKU ${prefix_drugi_potok}${NR_FILOZOFA}"
    (filozof ${NR_FILOZOFA} $KATALOG_STOLU ${LICZBA_POSILKOW} ${CZAS_KONSUMOWANIA} ${CZAS_ROZMYSLANIA} ${LICZBA_FILOZOFOW} "${prefix_pierwszy_potok}${NR_FILOZOFA}" "${prefix_drugi_potok}${NR_FILOZOFA}" ) &
done


for nr_filozofa in $(seq 1 ${LICZBA_FILOZOFOW}); do
    cat ${prefix_pierwszy_potok}$nr_filozofa >> /dev/null
done

for nr_filozofa in $(seq 1 ${LICZBA_FILOZOFOW}); do
    echo "kontynuuj" >> ${prefix_drugi_potok}$nr_filozofa
done

wait

#Sprzatanie
komunikat "Czy chesz posprzatac utworzone przez skrypt pliki? (T/t)"
read sprzataj

if [[ $sprzataj == "T" || $sprzataj == "t" ]]; then

for nr_filozofa in $(seq 1 ${LICZBA_FILOZOFOW}); do
    rm -f ${prefix_pierwszy_potok}$nr_filozofa
	sprawdz_blad
    rm -f ${prefix_drugi_potok}$nr_filozofa
	sprawdz_blad
done

for nr_widelca in $(seq 1 ${LICZBA_FILOZOFOW}); do
    rm -f ${KATALOG_STOLU}/$nr_widelca
	sprawdz_blad
done

rm -fd ${KATALOG_STOLU}
sprawdz_blad

fi

wait

exit 0
