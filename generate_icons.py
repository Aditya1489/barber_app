#!/usr/bin/env python3
"""
Generate app icons for Android and iOS from a source image.
Extracts the center portion of the image (removing phone frame) and creates all required sizes.
"""

from PIL import Image
import os

# Source image path
SOURCE_IMAGE = "/Users/adityachavhan/Documents/Final_Project/barber_app/assets/logo_source.png"

# Android icon sizes (in mipmap folders)
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Base paths
BARBER_ANDROID_RES = "/Users/adityachavhan/Documents/Final_Project/barber_app/android/app/src/main/res"
CUSTOMER_ANDROID_RES = "/Users/adityachavhan/Documents/Final_Project/customer_app/android/app/src/main/res"

def extract_logo_center(source_path):
    """Extract the center portion of the image (logo without phone frame)"""
    img = Image.open(source_path)
    width, height = img.size
    
    # The logo is in the center of the phone screen
    # Estimate: crop to center 60% of the image
    crop_size = min(width, height) * 0.6
    left = (width - crop_size) / 2
    top = (height - crop_size) / 2
    right = left + crop_size
    bottom = top + crop_size
    
    logo = img.crop((left, top, right, bottom))
    return logo

def generate_android_icons(logo, base_res_path):
    """Generate Android app icons in all required sizes"""
    for folder, size in ANDROID_SIZES.items():
        folder_path = os.path.join(base_res_path, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Resize logo
        resized = logo.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save as ic_launcher.png
        output_path = os.path.join(folder_path, "ic_launcher.png")
        resized.save(output_path, "PNG")
        print(f"✅ Created: {output_path}")

def main():
    print("🎨 Extracting logo from source image...")
    logo = extract_logo_center(SOURCE_IMAGE)
    
    print(f"\n📱 Generating Android icons for Barber App...")
    generate_android_icons(logo, BARBER_ANDROID_RES)
    
    print(f"\n📱 Generating Android icons for Customer App...")
    generate_android_icons(logo, CUSTOMER_ANDROID_RES)
    
    print("\n✨ All icons generated successfully!")
    print("\n⚠️  Note: iOS icons require manual setup or use flutter_launcher_icons package")

if __name__ == "__main__":
    main()
