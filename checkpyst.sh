#!/bin/bash

# ANSI colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"  # Reset color

# Check if at least one file is provided
if [ "$#" -lt 1 ]; then
    echo -e "${RED}Error: Please provide at least one .py file.${NC}"
    exit 1
fi

echo -e "\n"
echo "########################################################################"
echo "#              _____ _               _                                 #"
echo "#            / ____| |             | |                                 #"
echo "#           | |    | |__   ___  ___| | ___ __  _   _ ___| |_           #"
echo "#           | |    | '_ \ / _ \/ __| |/ / '_ \| | | / __| __|          #"
echo "#           | |____| | | |  __/ (__|   <| |_) | |_| \__ \ |_           #"
echo "#            \_____|_| |_|\___|\___|_|\_\ .__/ \__, |___/\__|          #"
echo "#                                       | |     __/ |                  #"
echo "#                                       |_|    |___/                   #"
echo "#                                                                      #"
echo "########################################################################"
echo "#                    Check list for python file  (v1)                  #"
echo "########################################################################"
echo -e "\n"

# Check if pycodestyle is installed
if ! command -v pycodestyle &> /dev/null && ! python3 -m pycodestyle --version &> /dev/null; then
    echo -e "${RED}⚠ Warning: pycodestyle is not installed or not accessible.${NC}"
    echo -e "${YELLOW}You can install it with:${NC}"
    echo -e "${YELLOW}- Debian/Ubuntu: sudo apt install python3-pycodestyle${NC}"
    echo -e "${YELLOW}- Pip: pip install pycodestyle${NC}"
    echo -e "${YELLOW}- Check if it's available with: python3 -m pycodestyle --version${NC}\n"
fi

# Counters
total_files=0
total_problems=0

# Loop through provided files
for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File '$file' not found.${NC}"
        continue
    fi

    total_files=$((total_files + 1))
    file_problems=0

    echo -e "${YELLOW}Checking: $file${NC}"
    echo "========================================================================"

    # Check if the file is executable
    if [[ -x "$file" ]]; then
        echo -e "${GREEN}[OK]${NC} The file is executable (+x)"
    else
        echo -e "${RED}[ERROR]${NC} The file is not executable (+x missing)"
        file_problems=$((file_problems + 1))
    fi

    # Check if the Python file is valid (no syntax errors)
    python3 -m py_compile "$file" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[OK]${NC} The file is valid Python (no syntax errors)"
    else
        echo -e "${RED}[ERROR]${NC} The file contains syntax errors!"
        file_problems=$((file_problems + 1))
    fi

    # Check module documentation
    module_name=$(basename "$file" .py)
    doc_module=$(python3 -c "print(bool(__import__('$module_name').__doc__))" 2>/dev/null)
    if [[ "$doc_module" == "True" ]]; then
        echo -e "${GREEN}[OK]${NC} Documentation found for module '$module_name'"
    else
        echo -e "${RED}[ERROR]${NC} No documentation found for module '$module_name'"
        file_problems=$((file_problems + 1))
    fi

    # Check class documentation
    class_list=$(python3 -c "
import inspect
try:
    module = __import__('$module_name')
    classes = [cls for _, cls in inspect.getmembers(module, inspect.isclass)]
    if not classes:
        print('NO_CLASSES')
    for cls in classes:
        print(cls.__name__, bool(cls.__doc__))
except Exception as e:
    print('ERROR:', e)
" 2>/dev/null)

    if [[ "$class_list" == "NO_CLASSES" ]]; then
        echo -e "${YELLOW}[INFO]${NC} No classes found in the module."
    else
        while IFS= read -r line; do
            class_name=$(echo "$line" | awk '{print $1}')
            has_doc=$(echo "$line" | awk '{print $2}')
            if [[ "$has_doc" == "True" ]]; then
                echo -e "${GREEN}[OK]${NC} Documentation found for class '$class_name'"
            else
                echo -e "${RED}[ERROR]${NC} No documentation found for class '$class_name'"
                file_problems=$((file_problems + 1))
            fi
        done <<< "$class_list"
    fi

    # Check function documentation
    function_list=$(python3 -c "
import inspect
try:
    module = __import__('$module_name')
    functions = [func for _, func in inspect.getmembers(module, inspect.isfunction)]
    if not functions:
        print('NO_FUNCTIONS')
    for func in functions:
        print(func.__name__, bool(func.__doc__))
except Exception as e:
    print('ERROR:', e)
" 2>/dev/null)

    if [[ "$function_list" == "NO_FUNCTIONS" ]]; then
        echo -e "${YELLOW}[INFO]${NC} No functions found in the module."
    else
        while IFS= read -r line; do
            function_name=$(echo "$line" | awk '{print $1}')
            has_doc=$(echo "$line" | awk '{print $2}')
            if [[ "$has_doc" == "True" ]]; then
                echo -e "${GREEN}[OK]${NC} Documentation found for function '$function_name'"
            else
                echo -e "${RED}[ERROR]${NC} No documentation found for function '$function_name'"
                file_problems=$((file_problems + 1))
            fi
        done <<< "$function_list"
    fi

    # Check with pycodestyle (if installed)
    if command -v pycodestyle &> /dev/null; then
        pycodestyle_errors=$(pycodestyle "$file" | wc -l)
        if [[ "$pycodestyle_errors" -eq 0 ]]; then
            echo -e "${GREEN}[OK]${NC} No pycodestyle errors detected"
        else
            echo -e "${RED}[ERROR]${NC} $pycodestyle_errors issues detected by pycodestyle"
            pycodestyle "$file"
            file_problems=$((file_problems + 1))
        fi
    fi

    # Summary for this file
    if [[ "$file_problems" -eq 0 ]]; then
        echo -e "${GREEN}✔ No issues detected in '$file'${NC}"
    else
        echo -e "${RED}✘ $file_problems issue(s) found in '$file'${NC}"
    fi

    echo "========================================================================"
    echo ""

    total_problems=$((total_problems + file_problems))
done

# Global summary
echo -e "\n${YELLOW}┌───────────────────────────────────┐${NC}"
echo -e "${YELLOW}|          GLOBAL SUMMARY           |${NC}"
echo -e "${YELLOW}└───────────────────────────────────┘${NC}"

# Results (indented for clarity)
echo -e "\tTotal files checked: ${YELLOW}$total_files${NC}"
if [[ "$total_problems" -eq 0 ]]; then
    echo -e "\t${GREEN}✔ All files are compliant!${NC}"
else
    echo -e "\t${RED}✘ $total_problems issue(s) detected${NC}"
fi

echo ""

