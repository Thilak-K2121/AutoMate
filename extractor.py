import os

def main():
    # Define the exact files you want to extract, mapped to their target categories
    extraction_plan = {
        "backend": {
            "output_dir": "backendtxts",
            "prefix": "backend",
            "files": [
                "backend/server.js",
                "backend/src/config/db.js",
                "backend/src/controllers/authController.js",
                "backend/src/controllers/messageController.js",
                "backend/src/controllers/notificationController.js",
                "backend/src/controllers/rideController.js",
                "backend/src/middleware/authMiddleware.js",
                "backend/src/routes/authRoutes.js",
                "backend/src/routes/messageRoutes.js",
                "backend/src/routes/notificationRoutes.js",
                "backend/src/routes/rideRoutes.js",
                "backend/src/sockets/socketManager.js"
            ]
        },
        "frontend": {
            "output_dir": "frontendtxts",
            "prefix": "frontend",
            "files": [
                "frontend/flutter_app/lib/main.dart",
                "frontend/flutter_app/lib/services/api_service.dart",
                "frontend/flutter_app/lib/screens/chat_page.dart",
                "frontend/flutter_app/lib/screens/create_ride_page.dart",
                "frontend/flutter_app/lib/screens/home_page.dart",
                "frontend/flutter_app/lib/screens/map_page.dart",
                "frontend/flutter_app/lib/screens/metro_ride_details_page.dart",
                "frontend/flutter_app/lib/screens/my_rides_page.dart",
                "frontend/flutter_app/lib/screens/notifications_page.dart",
                "frontend/flutter_app/lib/screens/profile_page.dart",
                "frontend/flutter_app/lib/screens/register_page.dart",
                "frontend/flutter_app/lib/screens/ride_history_page.dart",
                "frontend/flutter_app/lib/screens/sign_in_page.dart",
                "frontend/flutter_app/lib/screens/splash_screen.dart"
            ]
        },
        "database": {
            "output_dir": "dbtxts",
            "prefix": "db",
            "files": [
                "database/init.sql"
            ]
        },
        "docker": {
            "output_dir": "dockertxts",
            "prefix": "docker",
            "files": [
                "docker-compose.yml",
                "backend/Dockerfile",
                "backend/package.json"
            ]
        }
    }

    for category, config in extraction_plan.items():
        # Create the specific output folder (e.g., frontendtxts)
        os.makedirs(config["output_dir"], exist_ok=True)
        
        counter = 1
        for file_path in config["files"]:
            # Ensure the file actually exists before trying to read it
            if os.path.exists(file_path):
                try:
                    with open(file_path, 'r', encoding='utf-8') as infile:
                        content = infile.read()
                    
                    # Construct the new filename (e.g., frontend1.txt)
                    out_filename = f"{config['prefix']}{counter}.txt"
                    out_path = os.path.join(config["output_dir"], out_filename)
                    
                    # Write the formatted output
                    with open(out_path, 'w', encoding='utf-8') as outfile:
                        outfile.write(f"File Name: {os.path.basename(file_path)}\n")
                        outfile.write(f"Location: {file_path}\n")
                        outfile.write("-" * 50 + "\n\n")
                        outfile.write(content)
                        outfile.write("\n")
                    
                    print(f"✅ Created {out_path} from {file_path}")
                    counter += 1
                except Exception as e:
                    print(f"❌ Error reading {file_path}: {e}")
            else:
                print(f"⚠️ Warning: Could not find {file_path}. Skipping.")

if __name__ == "__main__":
    main()