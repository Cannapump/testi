<?php
session_start();
require_once 'db.php';

// הפעלת דיווח על שגיאות
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// בדוק אם המשתמש מחובר
if (!isset($_SESSION['user_id'])) {
    header("Location: login.php");
    exit();
}

$db = new Database();
$conn = $db->getConnection();

$userId = $_SESSION['user_id']; // מזהה המשתמש הנוכחי

// טיפול בהוספת מוצר חדש
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['add_product'])) {
    $name = $_POST['name'];
    $barcode = $_POST['barcode'];
    $description = $_POST['description'];
    $quantity = $_POST['quantity'];
    $price = isset($_POST['price']) ? $_POST['price'] : 0;
    $assignedUserId = isset($_POST['assigned_user']) && !empty($_POST['assigned_user']) ? $_POST['assigned_user'] : $userId;
    $category = $_POST['category'];

    if (!is_numeric($assignedUserId)) {
        echo 'שגיאה: מזהה משתמש אינו תקין.';
        exit();
    }

    try {
        // בדוק אם הברקוד כבר קיים עבור אותו משתמש
        $stmt = $conn->prepare("SELECT COUNT(*) FROM products WHERE barcode = :barcode AND user_id = :user_id");
        $stmt->bindParam(':barcode', $barcode);
        $stmt->bindParam(':user_id', $userId);
        $stmt->execute();

        if ($stmt->fetchColumn() > 0) {
            echo 'שגיאה: ברקוד זה כבר קיים עבור המשתמש שלך.';
            exit();
        }

        // הכנס את המוצר למסד הנתונים
        $stmt = $conn->prepare("INSERT INTO products (name, barcode, description, quantity, price, user_id, category) VALUES (:name, :barcode, :description, :quantity, :price, :user_id, :category)");
        $stmt->bindParam(':name', $name);
        $stmt->bindParam(':barcode', $barcode);
        $stmt->bindParam(':description', $description);
        $stmt->bindParam(':quantity', $quantity);
        $stmt->bindParam(':price', $price);
        $stmt->bindParam(':user_id', $assignedUserId);
        $stmt->bindParam(':category', $category);
        $stmt->execute();
    } catch (Exception $e) {
        echo 'שגיאה בהוספת מוצר: ',  $e->getMessage(), "\n";
    }
}

// טיפול במחיקת מוצר
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['delete_product'])) {
    $id = $_POST['id'];

    try {
        // בדוק אם המשתמש הוא מנהל או אם המוצר שייך לו
        if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']) {
            $stmt = $conn->prepare("DELETE FROM products WHERE id = :id");
        } else {
            $stmt = $conn->prepare("DELETE FROM products WHERE id = :id AND user_id = :user_id");
            $stmt->bindParam(':user_id', $userId);
        }

        $stmt->bindParam(':id', $id);
        $stmt->execute();
    } catch (Exception $e) {
        echo 'שגיאה במחיקת מוצר: ',  $e->getMessage(), "\n";
    }
}

// קבלת כל הקטגוריות הייחודיות
$stmt = $conn->query("SELECT DISTINCT category FROM products ORDER BY category");
$categories = $stmt->fetchAll(PDO::FETCH_COLUMN);

// קבלת כל המוצרים (בהתאם לתפקיד המשתמש ולסינון)
try {
    if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']) {
        // אם המנהל בחר משתמש, סנן לפי משתמש זה
        if (isset($_GET['filter_user']) && !empty($_GET['filter_user'])) {
            $filterUserId = $_GET['filter_user'];
            $stmt = $conn->prepare("SELECT p.*, u.username FROM products p JOIN users u ON p.user_id = u.id WHERE p.user_id = :user_id ORDER BY p.category, p.name");
            $stmt->bindParam(':user_id', $filterUserId);
        } else {
            $stmt = $conn->query("SELECT p.*, u.username FROM products p JOIN users u ON p.user_id = u.id ORDER BY p.category, p.name");
        }
    } else {
        $stmt = $conn->prepare("SELECT * FROM products WHERE user_id = :user_id ORDER BY category, name");
        $stmt->bindParam(':user_id', $userId);
    }

    // סינון לפי קטגוריה (עבור כל המשתמשים)
    if (isset($_GET['filter_category']) && !empty($_GET['filter_category'])) {
        $filterCategory = $_GET['filter_category'];
        if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']) {
            $stmt = $conn->prepare("SELECT p.*, u.username FROM products p JOIN users u ON p.user_id = u.id WHERE p.category = :category ORDER BY p.name");
        } else {
            $stmt = $conn->prepare("SELECT * FROM products WHERE user_id = :user_id AND category = :category ORDER BY name");
            $stmt->bindParam(':user_id', $userId);
        }
        $stmt->bindParam(':category', $filterCategory);
    }

    $stmt->execute();
    $products = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    echo 'שגיאה בהבאת מוצרים: ',  $e->getMessage(), "\n";
}

// קבלת רשימת המשתמשים (רק למנהל)
if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']) {
    try {
        $stmt = $conn->query("SELECT id, username FROM users ORDER BY username");
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        echo 'שגיאה בהבאת משתמשים: ',  $e->getMessage(), "\n";
    }
}
?>

<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ניהול מוצרים - מערכת ניהול מלאי</title>
    <style>
        /* הסגנון נשאר ללא שינוי */
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
        }
        .container {
            max-width: 1200px;
            margin: 20px auto;
            background-color: #fff;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
        }
        h1, h2 {
            color: #2e8b57;
        }
        form {
            margin-bottom: 20px;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 8px;
            background-color: #f9f9f9;
        }
        input[type="text"], input[type="number"], select {
            width: 100%;
            padding: 10px;
            margin-bottom: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        input[type="submit"], button {
            background-color: #4CAF50;
            color: white;
            padding: 10px 15px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        input[type="submit"]:hover, button:hover {
            background-color: #45a049;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        th, td {
            padding: 12px;
            border: 1px solid #ddd;
            text-align: right;
        }
        th {
            background-color: #e9f7e9;
        }
        td a {
            color: #4CAF50;
            text-decoration: none;
        }
        td a:hover {
            text-decoration: underline;
        }
        .actions {
            margin-top: 20px;
            text-align: center;
        }
        .actions a {
            display: inline-block;
            margin: 0 10px;
            padding: 10px 20px;
            background-color: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            font-size: 16px;
        }
        .actions a:hover {
            background-color: #45a049;
        }

        @media (max-width: 768px) {
            table, th, td {
                display: block;
                width: 100%;
            }
            th, td {
                box-sizing: border-box;
                width: 100%;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>ניהול מוצרים</h1>

        <?php if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']): ?>
        <h2>הוסף מוצר</h2>
        <form action="manage_products.php" method="post">
            <input type="text" name="name" placeholder="שם מוצר" required>
            <input type="text" name="barcode" placeholder="ברקוד" required>
            <input type="text" name="description" placeholder="תיאור">
            <input type="number" name="quantity" placeholder="כמות" required>
            <input type="number" name="price" placeholder="מחיר">
            <select name="category" required>
                <option value="">בחר קטגוריה</option>
                <option value="מצברים וסוללות">מצברים וסוללות</option>
                <option value="מגבים">מגבים</option>
                <option value="מנורות">מנורות</option>
                <option value="שונות">שונות</option>
            </select>
            <select name="assigned_user">
                <option value="">בחר משתמש (ברירת מחדל: אתה)</option>
                <?php foreach ($users as $user): ?>
                    <option value="<?php echo htmlspecialchars($user['id']); ?>"><?php echo htmlspecialchars($user['username']); ?></option>
                <?php endforeach; ?>
            </select>
            <input type="submit" name="add_product" value="הוסף מוצר">
        </form>

        <h2>סינון לפי משתמש</h2>
        <form method="get">
            <select name="filter_user">
                <option value="">בחר משתמש</option>
                <?php foreach ($users as $user): ?>
                    <option value="<?php echo htmlspecialchars($user['id']); ?>" <?php echo isset($_GET['filter_user']) && $_GET['filter_user'] == $user['id'] ? 'selected' : ''; ?>>
                        <?php echo htmlspecialchars($user['username']); ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <input type="submit" value="סנן">
        </form>
        <?php else: ?>
        <h2>הוסף מוצר</h2>
        <form action="manage_products.php" method="post">
            <input type="text" name="name" placeholder="שם מוצר" required>
            <input type="text" name="barcode" placeholder="ברקוד" required>
            <input type="text" name="description" placeholder="תיאור">
            <input type="number" name="quantity" placeholder="כמות" required>
            <input type="number" name="price" step="0.01" value="0" readonly>
            <select name="category" required>
                <option value="">בחר קטגוריה</option>
                <option value="מצברים וסוללות">מצברים וסוללות</option>
                <option value="מגבים">מגבים</option>
                <option value="מנורות">מנורות</option>
                <option value="שונות">שונות</option>
            </select>
            <input type="submit" name="add_product" value="הוסף מוצר">
        </form>
        <?php endif; ?>

        <h2>סינון לפי קטגוריה</h2>
        <form method="get">
            <select name="filter_category">
                <option value="">בחר קטגוריה</option>
                <?php foreach ($categories as $category): ?>
                    <option value="<?php echo htmlspecialchars($category); ?>" <?php echo isset($_GET['filter_category']) && $_GET['filter_category'] == $category ? 'selected' : ''; ?>>
                        <?php echo htmlspecialchars($category); ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <input type="submit" value="סנן">
        </form>

        <h2>רשימת מוצרים</h2>
        <table>
            <thead>
                <tr>
                    <th>שם</th>
                    <th>ברקוד</th>
                    <th>תיאור</th>
                    <th>כמות</th>
                    <?php if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']): ?>
                        <th>מחיר</th>
                    <?php endif; ?>
                    <th>קטגוריה</th>
                    <th>בעל מוצר</th>
                    <th>פעולות</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($products as $product): ?>
                    <tr>
                        <td><?php echo htmlspecialchars($product['name']); ?></td>
                        <td><?php echo htmlspecialchars($product['barcode']); ?></td>
                        <td><?php echo htmlspecialchars($product['description']); ?></td>
                        <td><?php echo htmlspecialchars($product['quantity']); ?></td>
                        <?php if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']): ?>
                            <td><?php echo htmlspecialchars($product['price']); ?></td>
                        <?php endif; ?>
                        <td><?php echo htmlspecialchars($product['category']); ?></td>
                        <td><?php echo isset($product['username']) ? htmlspecialchars($product['username']) : 'לא זמין'; ?></td>
                        <td>
                            <form action="manage_products.php" method="post" style="display:inline;">
                                <input type="hidden" name="id" value="<?php echo $product['id']; ?>">
                                <input type="submit" name="delete_product" value="מחק" onclick="return confirm('האם אתה בטוח שברצונך למחוק מוצר זה?');">
                            </form>
                            <?php if (isset($_SESSION['is_admin']) && $_SESSION['is_admin']): ?>
                                <a href="edit_product.php?id=<?php echo $product['id']; ?>">ערוך</a>
                            <?php endif; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>

        <div class="actions">
            <a href="dashboard.php">חזרה לדף הבית</a>
            <a href="manage_categories.php">עריכת קטגוריות</a>

        </div>
    </div>
</body>
</html>
