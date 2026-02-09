#!/bin/bash
# Generate app icons using macOS sips command

SOURCE="/Users/adityachavhan/Documents/Final_Project/barber_app/assets/logo_source.png"
BARBER_RES="/Users/adityachavhan/Documents/Final_Project/barber_app/android/app/src/main/res"
CUSTOMER_RES="/Users/adityachavhan/Documents/Final_Project/customer_app/android/app/src/main/res"

# First, crop the center portion to extract just the logo (remove phone frame)
TEMP_LOGO="/tmp/barber_logo_cropped.png"
sips -c 800 800 "$SOURCE" --out "$TEMP_LOGO" > /dev/null 2>&1

echo "🎨 Extracted logo from source image"

# Function to generate icons
generate_icons() {
    local RES_PATH=$1
    local APP_NAME=$2
    
    echo ""
    echo "📱 Generating icons for $APP_NAME..."
    
    # mipmap-mdpi: 48x48
    mkdir -p "$RES_PATH/mipmap-mdpi"
    sips -z 48 48 "$TEMP_LOGO" --out "$RES_PATH/mipmap-mdpi/ic_launcher.png" > /dev/null 2>&1
    echo "  ✅ Created: mipmap-mdpi/ic_launcher.png (48x48)"
    
    # mipmap-hdpi: 72x72
    mkdir -p "$RES_PATH/mipmap-hdpi"
    sips -z 72 72 "$TEMP_LOGO" --out "$RES_PATH/mipmap-hdpi/ic_launcher.png" > /dev/null 2>&1
    echo "  ✅ Created: mipmap-hdpi/ic_launcher.png (72x72)"
    
    # mipmap-xhdpi: 96x96
    mkdir -p "$RES_PATH/mipmap-xhdpi"
    sips -z 96 96 "$TEMP_LOGO" --out "$RES_PATH/mipmap-xhdpi/ic_launcher.png" > /dev/null 2>&1
    echo "  ✅ Created: mipmap-xhdpi/ic_launcher.png (96x96)"
    
    # mipmap-xxhdpi: 144x144
    mkdir -p "$RES_PATH/mipmap-xxhdpi"
    sips -z 144 144 "$TEMP_LOGO" --out "$RES_PATH/mipmap-xxhdpi/ic_launcher.png" > /dev/null 2>&1
    echo "  ✅ Created: mipmap-xxhdpi/ic_launcher.png (144x144)"
    
    # mipmap-xxxhdpi: 192x192
    mkdir -p "$RES_PATH/mipmap-xxxhdpi"
    sips -z 192 192 "$TEMP_LOGO" --out "$RES_PATH/mipmap-xxxhdpi/ic_launcher.png" > /dev/null 2>&1
    echo "  ✅ Created: mipmap-xxxhdpi/ic_launcher.png (192x192)"
}

# Generate for both apps
generate_icons "$BARBER_RES" "Barber App"
generate_icons "$CUSTOMER_RES" "Customer App"

# Cleanup
rm "$TEMP_LOGO"

echo ""
echo "✨ All Android icons generated successfully!"
