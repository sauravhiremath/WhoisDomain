#! /bin/bash
export PATH=".:$PATH"

DATE=$( date +%Y%m%d )
VERSION_FILE="work/version"

setupVersionNumberToday()
{
    VERSION="1" # we start with version 1, only breaking changes will increment the first digit

    # while preparing the test.pypi we increment the day sequence if needed,
    # only a last version actually later will get published to the actual pypi (non test)

    TODAY_SEQ=$(
        ls dist/*${DATE}*.whl 2>/dev/null |
        awk -F\- '{ print $2 }' |
        awk -F\. '{ print $3 }' |
        awk '{ if ($1 > a) { a = $1 }} END { print a }'
    )

    if [ -z "${TODAY_SEQ}" ]
    then
        TODAY_SEQ="1"
    else
        TODAY_SEQ=$(( TODAY_SEQ + 1))
    fi

    mkdir -p ./work/
    # keep track of the latest version string
    echo "${VERSION}.${DATE}.${TODAY_SEQ}" >"./${VERSION_FILE}"
    echo "VERSION = \"${VERSION}.${DATE}.${TODAY_SEQ}\"" >whoisdomain/version.py
}

makeTomlFile()
{
    return

    cat pyproject.toml-template |
    awk -vversion="${VERSION}" -vdate="${DATE}" -vseq="${TODAY_SEQ}" '
    /@VERSION@/  { sub(/@VERSION@/,version) }
    /@YYYYMMDD@/ { sub(/@YYYYMMDD@/,date) }
    /@SEQ@/      { sub(/@SEQ@/,seq) }
    { print }
    ' >pyproject.toml
}

buildDist()
{
    python -m build
    ls -l dist
}

main()
{
    what="$1"

    [ "$what" != "force" ]  && {
        # do we have a version
        [ -f "${VERSION_FILE}" ] && {
            # is it today
            grep $DATE "${VERSION_FILE}" && {
                # any changes in the actual code
                git status whoisdomain README.md | grep modified || {
                    exit 0
                }
            }
        }
    }

    bin/reformat-code.sh

    setupVersionNumberToday
    buildDist
    V=$(cat "${VERSION_FILE}")

    git add .
    git commit -a -m "version ${V}"
    git tag -m "version ${V}"  ${V}
    git push --tags
}

main $*
