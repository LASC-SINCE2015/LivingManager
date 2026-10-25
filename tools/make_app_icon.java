import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.GradientPaint;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.Arc2D;
import java.awt.geom.Ellipse2D;
import java.awt.geom.Path2D;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

/**
 * アプリアイコン（にっこり顔のおうち）の PNG を作る。
 *
 * 使い方（リポジトリのルートで実行。Java 11 以降ならコンパイル不要）:
 *   java tools/make_app_icon.java app/web
 *
 * 512×512 の座標で描き、出力サイズに合わせて拡大・縮小する。
 *
 * ファイル名には VERSION を入れる。ホーム画面に追加済みのアプリは同じ URL の画像を
 * 使い続けるため、絵を変えたら VERSION を上げ、manifest.json と index.html の参照も変える。
 */
public class make_app_icon {
  static final String VERSION = "v2";

  static final Color BG_TOP = new Color(0x8CC4AE);
  static final Color BG_BOTTOM = new Color(0x4F8A78);
  static final Color HOUSE = new Color(0xFFF8EC);
  static final Color ROOF = new Color(0xF28C7A);
  static final Color FACE = new Color(0x3B3B3B);
  static final Color CHEEK = new Color(0xF7A8A0);
  static final Color BADGE = new Color(0xFFD36E);

  public static void main(String[] args) throws Exception {
    File web = new File(args.length > 0 ? args[0] : "app/web");
    String prefix = "icons/icon-" + VERSION + "-";
    write(new File(web, prefix + "192.png"), 192, false);
    write(new File(web, prefix + "512.png"), 512, false);
    write(new File(web, prefix + "maskable-192.png"), 192, true);
    write(new File(web, prefix + "maskable-512.png"), 512, true);
    // iPhone は透明な部分を黒く塗るので、端まで背景を塗った絵にする（角は iPhone が丸める）
    write(new File(web, prefix + "apple-180.png"), 180, true);
    write(new File(web, prefix + "favicon-32.png"), 32, false);
  }

  /** maskable は端まで背景で塗り、絵は切り取られない中央 80% に収める */
  static void write(File file, int size, boolean maskable) throws Exception {
    BufferedImage img = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
    Graphics2D g = img.createGraphics();
    g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
    g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
    g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
    g.scale(size / 512.0, size / 512.0);

    g.setPaint(new GradientPaint(0, 0, BG_TOP, 0, 512, BG_BOTTOM));
    if (maskable) {
      g.fillRect(0, 0, 512, 512);
      g.translate(256, 256);
      g.scale(0.8, 0.8);
      g.translate(-256, -256);
    } else {
      g.fill(new RoundRectangle2D.Double(0, 0, 512, 512, 224, 224));
    }
    drawHouse(g);
    g.dispose();

    file.getParentFile().mkdirs();
    ImageIO.write(img, "png", file);
    System.out.println("wrote " + file);
  }

  static void drawHouse(Graphics2D g) {
    // 影
    g.setColor(new Color(0, 0, 0, 40));
    g.fill(new Ellipse2D.Double(130, 404, 252, 26));

    // えんとつ
    g.setColor(ROOF);
    g.fill(new RoundRectangle2D.Double(322, 120, 46, 90, 16, 16));

    // 本体
    g.setColor(HOUSE);
    g.fill(new RoundRectangle2D.Double(140, 218, 232, 196, 56, 56));

    // 屋根（角を丸めた三角形）
    Path2D roof = new Path2D.Double();
    roof.moveTo(256, 112);
    roof.lineTo(112, 244);
    roof.lineTo(400, 244);
    roof.closePath();
    g.setColor(ROOF);
    g.fill(roof);
    g.setStroke(new BasicStroke(44, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
    g.draw(roof);

    // 顔: 目
    g.setColor(FACE);
    g.fill(new Ellipse2D.Double(203, 294, 24, 28));
    g.fill(new Ellipse2D.Double(285, 294, 24, 28));
    // 目のハイライト
    g.setColor(Color.WHITE);
    g.fill(new Ellipse2D.Double(211, 299, 8, 8));
    g.fill(new Ellipse2D.Double(293, 299, 8, 8));

    // 顔: ほっぺ
    g.setColor(new Color(CHEEK.getRed(), CHEEK.getGreen(), CHEEK.getBlue(), 200));
    g.fill(new Ellipse2D.Double(168, 330, 40, 24));
    g.fill(new Ellipse2D.Double(304, 330, 40, 24));

    // 顔: 口
    g.setColor(FACE);
    g.setStroke(new BasicStroke(10, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
    g.draw(new Arc2D.Double(228, 310, 56, 44, 200, 140, Arc2D.OPEN));

    // チェックのバッジ（在庫チェック）
    g.setColor(Color.WHITE);
    g.fill(new Ellipse2D.Double(334, 334, 116, 116));
    g.setColor(BADGE);
    g.fill(new Ellipse2D.Double(344, 344, 96, 96));
    Path2D check = new Path2D.Double();
    check.moveTo(368, 394);
    check.lineTo(386, 412);
    check.lineTo(418, 374);
    g.setColor(Color.WHITE);
    g.setStroke(new BasicStroke(14, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
    g.draw(check);
  }
}
