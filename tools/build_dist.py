import os
import zipfile

def build_dist():
    os.makedirs("dist", exist_ok=True)
    
    # 1. grm_single_addon.zip (grm/lua/...)
    with zipfile.ZipFile("dist/grm_single_addon.zip", "w", zipfile.ZIP_DEFLATED) as z:
        if os.path.exists("addon.txt"):
            z.write("addon.txt", "grm/addon.txt")
        else:
            z.writestr("grm/addon.txt", '"AddonInfo"\n{\n\t"name"\t\t"GRM RP Core"\n\t"version"\t"3.0"\n}\n')
            
        for root, dirs, files in os.walk("lua"):
            for f in files:
                filepath = os.path.join(root, f)
                arcname = os.path.join("grm", filepath)
                z.write(filepath, arcname)

    # 2. grm_full_code.zip (lua/...)
    with zipfile.ZipFile("dist/grm_full_code.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk("lua"):
            for f in files:
                filepath = os.path.join(root, f)
                z.write(filepath, filepath)

    # 3. grm_economy.zip (economy-related lua files)
    economy_files = [
        "lua/autorun/sh_grm_currency.lua",
        "lua/autorun/sh_grm_economy.lua",
        "lua/autorun/sh_grm_admin_menu.lua",
        "lua/autorun/client/cl_grm_hud.lua",
        "lua/autorun/sh_grm_tab_menu.lua",
        "lua/entities/grm_bank_terminal/shared.lua",
        "lua/entities/grm_bank_terminal/init.lua",
        "lua/entities/grm_bank_terminal/cl_init.lua",
    ]
    with zipfile.ZipFile("dist/grm_economy.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for f in economy_files:
            if os.path.exists(f):
                z.write(f, f)

    # 4. grm_fix_hud_tab_currency.zip
    fix_files = [
        "lua/autorun/sh_grm_currency.lua",
        "lua/autorun/client/cl_grm_hud.lua",
        "lua/autorun/sh_grm_tab_menu.lua",
    ]
    with zipfile.ZipFile("dist/grm_fix_hud_tab_currency.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for f in fix_files:
            if os.path.exists(f):
                z.write(f, f)

    print("All 4 dist archives generated successfully.")

if __name__ == "__main__":
    build_dist()
