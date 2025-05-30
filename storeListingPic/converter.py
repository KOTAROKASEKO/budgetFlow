from PIL import Image
import os

# 出力フォルダ名を指定
output_folder = "crop_images"

def crop_to_16_9(image_path, output_path):
    """
    Crops an image to a 16:9 aspect ratio from the center.

    Args:
        image_path (str): Path to the input image.
        output_path (str): Path to save the cropped image (including the output folder).
    """
    try:
        img = Image.open(image_path)
        orig_width, orig_height = img.size
        target_aspect = 16.0 / 9.0
        current_aspect = float(orig_width) / float(orig_height)

        print(f"Processing {image_path}: Original size {orig_width}x{orig_height} (Aspect: {current_aspect:.2f})")

        # --- クロップロジック (変更なし) ---
        if abs(current_aspect - target_aspect) < 0.01:
            print(f"  Image is already close to 16:9. Saving copy to {output_path}")
            # アスペクト比が既に近い場合でも、指定された出力パスにコピーを保存
            img.save(output_path)
            return

        if current_aspect > target_aspect:
            # Image is wider than 16:9 (crop width)
            new_width = int(target_aspect * orig_height)
            offset = (orig_width - new_width) / 2
            crop_box = (offset, 0, orig_width - offset, orig_height)
            print(f"  Cropping width. Box: ({crop_box[0]:.0f}, {crop_box[1]}, {crop_box[2]:.0f}, {crop_box[3]})")
        else:
            # Image is taller than 16:9 (crop height)
            new_height = int(orig_width / target_aspect)
            offset = (orig_height - new_height) / 2
            crop_box = (0, offset, orig_width, orig_height - offset)
            print(f"  Cropping height. Box: ({crop_box[0]}, {crop_box[1]:.0f}, {crop_box[2]}, {crop_box[3]:.0f})")

        # Ensure crop_box coordinates are integers
        crop_box_int = tuple(map(int, crop_box))

        # Crop the image
        cropped_img = img.crop(crop_box_int)
        new_width, new_height = cropped_img.size
        print(f"  Saving cropped image ({new_width}x{new_height}) to {output_path}") # 出力パスを表示
        cropped_img.save(output_path) # 指定された出力パスに保存

    except FileNotFoundError:
        print(f"Error: File not found at {image_path}")
    except Exception as e:
        print(f"An error occurred processing {image_path}: {e}")

# --- Main Execution ---
if __name__ == "__main__":
    # 元の画像ファイル名
    image_filenames = ["1.png", "2.png", "3.png", "4.png"]

    # 出力フォルダが存在しない場合は作成
    try:
        os.makedirs(output_folder, exist_ok=True) # exist_ok=True でフォルダが既に存在してもエラーにならない
        print(f"Output directory '{output_folder}' ensured/created.")
    except OSError as e:
        print(f"Error creating directory {output_folder}: {e}")
        # ディレクトリ作成に失敗した場合はスクリプトを終了するなどの処理も可能
        exit() # スクリプトを停止

    # 各画像を処理
    for filename in image_filenames:
        input_filepath = filename # スクリプトと同じディレクトリにあると仮定

        if os.path.exists(input_filepath):
            # 出力ファイルのフルパスを作成 (例: "crop_images/1.png")
            output_filepath = os.path.join(output_folder, filename)

            # クロップ関数を呼び出し
            crop_to_16_9(input_filepath, output_filepath)
        else:
            print(f"Skipping {filename}: Input file does not exist.")

    print("\nProcessing complete.")