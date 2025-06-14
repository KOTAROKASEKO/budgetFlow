from PIL import Image

def remove_background(image_path):
    # Open the image
    img = Image.open(image_path)
    
    # Convert image to RGBA if not already in that format (to handle transparency)
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Get image dimensions
    width, height = img.size
    
    # Create a new blank image with a white background
    white_bg = Image.new('RGBA', img.size, (255, 255, 255, 255))
    
    # Create a mask from the original image (considering transparency)
    mask = Image.new('L', img.size, 0)
    for x in range(width):
        for y in range(height):
            alpha = img.getpixel((x, y))[3]
            mask.putpixel((x, y), alpha)
    
    # Apply the mask to the new white background image
    img_no_bg = Image.composite(img, white_bg, mask)
    
    # Save or display the resulting image
    img_no_bg.show()  # Display the image (remove this if not needed)
    img_no_bg.save('output.png')  # Save the image to a file

# Example usage for each image from image0.png to image7.png
for i in range(8):
    image_path = f'image{i}.png'
    remove_background(image_path)
