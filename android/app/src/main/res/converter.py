from PIL import Image
import os

def resize_image(input_image, output_image, size):
    """
    Resize image to the given size.

    :param input_image: input image path
    :param output_image: output image path
    :param size: tuple of width and height
    """
    image = Image.open(input_image)
    resized_image = image.resize(size)
    resized_image.save(output_image)

# Example usage
input_image = 'icon.png'  # Replace with your input image file path
sizes = [(48, 48), (72, 72), (96, 96), (144, 144), (192, 192)]
paths = ['mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi']

for index, size in enumerate(sizes):
    folder = paths[index]
    os.makedirs(folder, exist_ok=True)  # Create the folder if it doesn't exist
    output_image = os.path.join(folder, 'ic_launcher.png')
    resize_image(input_image, output_image, size)
