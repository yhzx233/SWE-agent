#!/usr/bin/env python3

# @yaml
# signature: |- 
#   add_function_to_class <file_name> <class_name>
#   <function_definition>
#   end_of_function
# docstring: Adds a function to the specified class in the given file. The function definition is terminated by a line with only end_of_function on it. All of the <function_definition> will be entered, so make sure your indentation is formatted properly. Python files will be checked for syntax errors after the edit. If the system detects a syntax error, the edit will not be executed. Simply try to edit the file again, but make sure to read the error message and modify the add_function_to_class command you issue accordingly. Issuing the same command a second time will just lead to the same error message again.
# end_name: end_of_function
# arguments:
#   file_name:
#     type: string
#     description: the name of the file where the class is located
#     required: true
#   class_name:
#     type: string
#     description: the name of the class to which the function will be added
#     required: true
#   function_definition:
#     type: string
#     description: the text of the function to add, terminated by a line with only end_of_function on it
#     required: true

import sys

def read_multiline_input():
    lines = []
    while True:
        try:
            line = input()
            if line.strip() == "end_of_function":
                break
        except EOFError:
            break
        lines.append(line)
    return "\n".join(lines)

def add_function_to_class(file_name, class_name, function_definition):
    with open(file_name, 'r') as file:
        lines = file.readlines()
    
    class_found = False
    in_multiline_comment = False
    class_indent = "    "
    insert_position = None
    
    for i, line in enumerate(lines):
        if '"""' in line or "'''" in line:
            in_multiline_comment = not in_multiline_comment
        
        if not in_multiline_comment:
            if line.strip().startswith(f"class {class_name}"):
                class_found = True
                # indent before class
                class_indent = line[:len(line) - len(line.lstrip())]
            elif class_found and line.strip().startswith("def "):
                insert_position = i
                # indent before def
                class_indent = line[:len(line) - len(line.lstrip())]
                break
            elif class_found and line.strip().startswith("class "):
                cur_indent = line[:len(line) - len(line.lstrip())]
                insert_position = i
                # new class
                if cur_indent == class_indent:
                    class_indent += "    "
                # inner class
                else:
                    insert_position = i
                    class_indent = cur_indent
                break

    if class_found and insert_position is not None:
        first_line = function_definition.split("\n")[0]
        # 调整为上面得到的intent
        delta_intent = class_indent[len(first_line) - len(first_line.lstrip()):]
        indented_function_definition = "\n".join([delta_intent + line for line in function_definition.split("\n")])
        lines.insert(insert_position, f"{indented_function_definition}\n\n")

        with open(file_name, 'w') as file:
            file.writelines(lines)

        print(f"Function added to class {class_name} in {file_name}")
    else:
        print(f"Class {class_name} not found in {file_name}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: add_function_to_class <file_name> <class_name>\n<function definition>")
        sys.exit(1)

    file_name = sys.argv[1]
    class_name = sys.argv[2]
    
    function_definition = read_multiline_input()

    add_function_to_class(file_name, class_name, function_definition)
