from PIL import Image
import os

# Load the original logo
logo = Image.open('adhyay_logo.png').convert('RGBA')

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
    mipmap_dir = f'android/app/src/main/res/mipmap-{density}'
    resized = logo.resize((size, size), Image.Resampling.LANCZOS)
    output_path = os.path.join(mipmap_dir, 'ic_launcher.png')
    resized.save(output_path)
    print(f'Created {output_path} ({size}x{size})')

print('Icon generation complete!')
