#!/bin/sh

die () {
	echo "$@" >&2
	exit 1
}

command_list () {
	grep -v '^#' "$1"
}

get_categories () {
	tr ' ' '\n'|
	grep -v '^$' |
	sort |
	uniq
}

category_list () {
	command_list "$1" |
	cut -c 40- |
	get_categories
}

get_synopsis () {
	sed -n '
		/^NAME/,/'"$1"'/H
		${
			x
			s/.*'"$1"' - \(.*\)/N_("\1")/
			p
		}' "Documentation/$1.txt"
}

define_categories () {
	echo
	echo "/* Command categories */"
	bit=0
	category_list "$1" |
	while read cat
	do
		echo "#define CAT_$cat (1UL << $bit)"
		bit=$(($bit+1))
	done
	test "$bit" -gt 32 && die "Urgh.. too many categories?"
}

print_command_list () {
	echo "static struct cmdname_help command_list[] = {"

	command_list "$1" |
	while read cmd rest
	do
		printf "	{ \"$cmd\", $(get_synopsis $cmd), 0"
		for cat in $(echo "$rest" | get_categories)
		do
			printf " | CAT_$cat"
		done
		echo " },"
	done
	echo "};"
}

echo "/* Automatically generated by generate-cmdlist.sh */
struct cmdname_help {
	const char *name;
	const char *help;
	uint32_t category;
};
"
if test -z "$2"
then
	define_categories "$1"
	echo
	print_command_list "$1"
	exit 0
fi

echo "static const char *common_cmd_groups[] = {"

grps=grps$$.tmp
match=match$$.tmp
trap "rm -f '$grps' '$match'" 0 1 2 3 15

sed -n '
	1,/^### common groups/b
	/^### command list/q
	/^#/b
	/^[ 	]*$/b
	h;s/^[^ 	][^ 	]*[ 	][ 	]*\(.*\)/	N_("\1"),/p
	g;s/^\([^ 	][^ 	]*\)[ 	].*/\1/w '$grps'
	' "$1"
printf '};\n\n'

n=0
substnum=
while read grp
do
	echo "^git-..*[ 	]$grp"
	substnum="$substnum${substnum:+;}s/[ 	]$grp/$n/"
	n=$(($n+1))
done <"$grps" >"$match"

printf 'static struct cmdname_help common_cmds[] = {\n'
grep -f "$match" "$1" |
sed 's/^git-//' |
sort |
while read cmd tags
do
	tag=$(echo "$tags" | sed "$substnum; s/[^0-9]//g")
	echo "	{\"$cmd\", $(get_synopsis git-$cmd), $tag},"
done
echo "};"
