import ast
import sys


def parse_gsettings_list(value):
    return ast.literal_eval(value.removeprefix("@as ").strip())


def format_gsettings_list(entries):
    return "[" + ", ".join(f"'{entry}'" for entry in entries) + "]"


def without_entry(entries, entry_identifier):
    return [entry for entry in entries if entry.split(":")[0] != entry_identifier]


def main():
    action, current_value, argument = sys.argv[1], sys.argv[2], sys.argv[3]
    entries = parse_gsettings_list(current_value)
    if action == "add":
        entries = without_entry(entries, argument.split(":")[0]) + [argument]
    else:
        entries = without_entry(entries, argument)
    print(format_gsettings_list(entries))


if __name__ == "__main__":
    main()
