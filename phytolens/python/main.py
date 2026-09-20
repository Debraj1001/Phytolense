import sys
import json
import socket
import threading

# Fallback imports if installed
try:
    import cv2
    import numpy as np
except ImportError:
    cv2 = None
    np = None

def process_image_features(image_path):
    if cv2 is None or np is None:
        return {
            "error": "OpenCV or NumPy not available",
            "brightness": 0.5,
            "contrast": 0.5,
            "sharpness": 0.5,
            "leaf_area_ratio": 0.5,
            "green_dominance": 1.0,
            "disease_area_ratio": 0.0,
            "estimated_distance_cm": 0.0,
            "exact_dimensions": {"width_cm": 0.0, "height_cm": 0.0}
        }
        
    try:
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError("Could not read image")
            
        # Example of OpenCV processing
        # 1. Convert to HSV for green segmentation
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        lower_green = np.array([35, 40, 40])
        upper_green = np.array([85, 255, 255])
        green_mask = cv2.inRange(hsv, lower_green, upper_green)
        
        # 2. Disease area (brown/yellow)
        lower_disease = np.array([10, 50, 50])
        upper_disease = np.array([35, 255, 255])
        disease_mask = cv2.inRange(hsv, lower_disease, upper_disease)
        
        total_pixels = img.shape[0] * img.shape[1]
        green_pixels = cv2.countNonZero(green_mask)
        disease_pixels = cv2.countNonZero(disease_mask)
        
        leaf_area_ratio = green_pixels / total_pixels if total_pixels > 0 else 0
        disease_area_ratio = disease_pixels / green_pixels if green_pixels > 0 else 0
        
        # 3. Brightness and Contrast
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        brightness = np.mean(gray) / 255.0
        contrast = np.std(gray) / 255.0
        
        # 4. Sharpness via Laplacian variance
        sharpness = cv2.Laplacian(gray, cv2.CV_64F).var() / 1000.0
        
        # Dimensions estimation (mock based on bounding box of leaf)
        contours, _ = cv2.findContours(green_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        width_cm = 0.0
        height_cm = 0.0
        if contours:
            c = max(contours, key=cv2.contourArea)
            x, y, w, h = cv2.boundingRect(c)
            # Assuming a reference scale of 100 pixels = 1 cm at standard distance
            width_cm = w / 100.0
            height_cm = h / 100.0

        return {
            "brightness": float(brightness),
            "contrast": float(contrast),
            "sharpness": float(sharpness),
            "leaf_area_ratio": float(leaf_area_ratio),
            "green_dominance": float(leaf_area_ratio * 1.5), 
            "disease_area_ratio": float(disease_area_ratio),
            "estimated_distance_cm": 15.0, # Dummy
            "exact_dimensions": {
                "width_cm": float(width_cm),
                "height_cm": float(height_cm)
            }
        }
    except Exception as e:
        return {"error": str(e)}

def handle_client(conn):
    try:
        data = conn.recv(4096)
        if not data:
            return
            
        request = json.loads(data.decode('utf-8'))
        action = request.get('action')
        
        if action == 'analyze_image':
            image_path = request.get('image_path')
            result = process_image_features(image_path)
            conn.sendall(json.dumps(result).encode('utf-8'))
            
    except Exception as e:
        error_res = {"error": str(e)}
        conn.sendall(json.dumps(error_res).encode('utf-8'))
    finally:
        conn.close()

def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(('127.0.0.1', 5999))
    server.listen(5)
    print("Python ML Server listening on port 5999", flush=True)
    
    while True:
        conn, addr = server.accept()
        threading.Thread(target=handle_client, args=(conn,)).start()

if __name__ == '__main__':
    start_server()
