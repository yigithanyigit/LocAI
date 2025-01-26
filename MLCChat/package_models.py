import json
import os
import shutil
from typing import Dict, List

def read_json(file_path: str) -> Dict:
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            return json.load(f)
    return {"model_list": []}

def write_json(data: Dict, file_path: str):
    with open(file_path, 'w') as f:
        json.dump(data, indent=2, fp=f)

def get_compiled_models(app_config_path: str) -> List[str]:
    app_config = read_json(app_config_path)
    return [model["model_id"] for model in app_config["model_list"]]

def main():
    PACKAGE_CONFIG = "mlc-package-config.json"
    APP_CONFIG = "dist/bundle/mlc-app-config.json"
    TEMP_DIR = "dist_temp"

    # Read configs
    package_config = read_json(PACKAGE_CONFIG)
    compiled_models = get_compiled_models(APP_CONFIG)

    # Filter new models
    new_models = [
        model for model in package_config["model_list"]
        if model["model_id"] not in compiled_models
    ]


    if not new_models:
        print("No new models to compile")
        return

    # Create temp config for new models
    temp_config = {
        "device": package_config.get("device", "iphone"),
        "model_list": new_models
    }
    write_json(temp_config, "temp_package_config.json")

    # Package new models
    os.system(f"mlc_llm package --package-config temp_package_config.json -o {TEMP_DIR}")

    # Merge new models
    temp_app_config = read_json(f"{TEMP_DIR}/bundle/mlc-app-config.json")
    app_config = read_json(APP_CONFIG)

    # Copy model files
    for model, model_origin in zip(temp_app_config["model_list"], temp_config["model_list"]):
        #model_lib = model["model_lib"]
        model_id = model["model_id"]
        bundle_weigth = model_origin["bundle_weight"] if "bundle_weight" in model_origin else False
        if bundle_weigth:
            shutil.copytree(
                f"{TEMP_DIR}/bundle/{model_id}",
                f"dist/bundle/{model_id}",
                dirs_exist_ok=True
            )

    # Update app config
    app_config["model_list"].extend(temp_app_config["model_list"])
    write_json(app_config, APP_CONFIG)

    # Cleanup
    shutil.rmtree(TEMP_DIR)
    os.remove("temp_package_config.json")

if __name__ == "__main__":
    main()