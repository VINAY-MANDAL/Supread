from PIL import Image
import os

# Get the directory where the script is located
script_dir = os.path.dirname(os.path.abspath(__file__))

# Load the original logo
logo_path = os.path.join(script_dir, 'adhyay_logo.png')
logo = Image.open(logo_path).convert('RGBA')

# Android icon sizes for different densities
sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192
}

# Create resized icons for each density
for density, size in sizes.items():
    mipmap_dir = os.path.join(script_dir, f'android/app/src/main/res/mipmap-{density}')
    os.makedirs(mipmap_dir, exist_ok=True)
    resized = logo.resize((size, size), Image.Resampling.LANCZOS)
    output_path = os.path.join(mipmap_dir, 'ic_launcher.png')
    resized.save(output_path)
    print(f'Created {output_path} ({size}x{size})')

print('Icon generation complete!')
