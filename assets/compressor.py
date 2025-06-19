from PIL import Image

def optimize_png_pillow(input_path, output_path, colors=256, max_size=(1024, 768)):
    """
    Pillowを使ってPNG画像を最適化（色数削減、リサイズ）します。
    """
    try:
        with Image.open(input_path) as img:
            # リサイズ
            img.thumbnail(max_size, Image.Resampling.LANCZOS) # LANCZOSは高品質なリサイズアルゴリズム

            if img.mode != 'P': # 'P'はパレットモード（256色以下）
                img = img.quantize(colors=colors)

            # 最適化オプションを付けて保存
            # optimize=Trueはファイルサイズを小さくしようと試みます
            #ただし、Pillowのoptimizeは他のツールほど強力ではありません
            img.save(output_path, format="PNG", optimize=True)
        print(f"'{input_path}'を'{output_path}'に最適化しました。")
    except Exception as e:
        print(f"エラーが発生しました: {e}")

# 使用例
input_file = "background.png"
output_file = "background.png"
optimize_png_pillow(input_file, output_file, colors=128, max_size=(800, 600))