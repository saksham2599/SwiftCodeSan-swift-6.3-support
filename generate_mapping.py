import os
import argparse

def generate_universal_mapping(root_path, output_file):
    root_path = os.path.abspath(root_path)
    mapping = []
    seen_files = set()
    module_locations = {}

    # Directories we should never treat as modules
    ignored_dirs = {'.git', '.build', '.xcodeproj', 'Tests', 'Pods', 'DerivedData', 'Resources', 'Support Files'}

    print(f"Scanning {root_path} for Swift modules...")

    for root, dirs, files in os.walk(root_path):
        # Prune ignored directories
        dirs[:] = [d for d in dirs if d not in ignored_dirs and not d.startswith('.')]

        # 1. SPM / Modern Structure Detection
        if 'Sources' in dirs:
            sources_path = os.path.join(root, 'Sources')
            for module_name in os.listdir(sources_path):
                module_path = os.path.join(sources_path, module_name)
                if os.path.isdir(module_path) and module_name not in ignored_dirs:
                    module_locations[module_name] = module_path
                    for m_root, _, m_files in os.walk(module_path):
                        for f in m_files:
                            if f.endswith(".swift"):
                                f_path = os.path.join(m_root, f)
                                if f_path not in seen_files:
                                    rel_path = os.path.relpath(f_path, os.getcwd())
                                    mapping.append(f"{rel_path}:{module_name}")
                                    seen_files.add(f_path)
            # Remove from dirs so walk doesn't repeat work inside Sources
            dirs.remove('Sources')

        # 2. Fallback for Non-SPM / Single-Target / Flat structures
        else:
            swift_files = [f for f in files if f.endswith(".swift")]
            if swift_files:
                # If these files haven't been captured by an SPM scan above
                unseen_swift = [f for f in swift_files if os.path.join(root, f) not in seen_files]
                
                if unseen_swift:
                    # Treat the current folder name as the module name
                    module_name = os.path.basename(root)
                    # If we are in the root itself or an empty name, use a default
                    if not module_name or root == root_path:
                        module_name = "MainTarget"
                    
                    for f in unseen_swift:
                        f_path = os.path.join(root, f)
                        rel_path = os.path.relpath(f_path, os.getcwd())
                        mapping.append(f"{rel_path}:{module_name}")
                        seen_files.add(f_path)

    with open(output_file, 'w') as f:
        f.write("\n".join(mapping))
    
    print(f"--- Universal Scan Results ---")
    print(f"Mapping saved to: {output_file}")
    print(f"Total Files Mapped: {len(mapping)}")
    print(f"Unique Modules Detected: {len(set(m.split(':')[1] for m in mapping))}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Universal Swift Module Mapper")
    parser.add_argument("path", help="Path to your project or monorepo")
    parser.add_argument("-o", "--output", default="mapping.txt", help="Output file name")
    args = parser.parse_args()
    generate_universal_mapping(args.path, args.output)
