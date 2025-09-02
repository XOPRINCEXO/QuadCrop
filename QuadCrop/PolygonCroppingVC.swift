//
//  PolygonCroppingVC.swift
//  iRed
//
//  Created by Prince on 13/06/25.
//  Copyright © 2025 ebest-iot. All rights reserved.
//

import UIKit
import Photos

// MARK: - PolygonCroppingVC
class PolygonCroppingVC: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var loaderView: UIView!
    @IBOutlet weak var loader: UIActivityIndicatorView!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var cropBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var cropCancelView: UIView!
    
    // MARK: - Crop Buttons (Corners)
    private let topLeftButton = UIButton()
    private let topRightButton = UIButton()
    private let bottomLeftButton = UIButton()
    private let bottomRightButton = UIButton()
    
    // MARK: - Crop Handles (Sides)
    private let topHandle = UIButton()
    private let bottomHandle = UIButton()
    private let leftHandle = UIButton()
    private let rightHandle = UIButton()
    
    // MARK: - Properties
    private var imageFrame: CGRect?
    private var editableImage: UIImage?
    
    private let rectangleLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let maskLayer = CAShapeLayer()
    
    private let buttonSize: CGFloat = 64
    private let minimumCroppedImageSize = 10 //in Kb
    
    private var activeButton: UIButton?
    private var activeButtonGesture: UIPanGestureRecognizer?
    
    var cropImage: UIImage? = UIImage(named: "TestImage")
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.manageLoader()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        self.setupDefaultCropRectangle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.navigationBar.isHidden = false
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    // MARK: - Actions
    @IBAction func cancelBtnTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: false)
    }
    
    @IBAction func cropBtnTapped(_ sender: Any) {
        guard let image = imageView.image, let imageFrame = self.imageFrame else {
            print("Could not unwrap original image bounds or editableOriginalImage")
            return
        }
        
        let pointsInImage = convertButtonCentersToImagePoints(imageFrame: imageFrame)
        
        guard pointsInImage.count == 4 else { return }
        
        cropImage(
            image: image,
            topLeft: pointsInImage[0],
            topRight: pointsInImage[1],
            bottomRight: pointsInImage[2],
            bottomLeft: pointsInImage[3]
        ) { [weak self] croppedImage in
            guard let self = self, let croppedImage = croppedImage else { return }
            self.handleCroppedImage(croppedImage)
            self.setupDefaultCropRectangle()
        }
    }
}

// MARK: - Helpers
extension PolygonCroppingVC {
    
    /// Show loader, setup image and crop views
    func manageLoader() {
        self.loader.startAnimating()
        self.loaderView.isHidden = false
        self.setupImage()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupViews()
            self.setupDefaultCropRectangle()
            self.loader.stopAnimating()
            self.mainView.layoutSubviews()
            self.viewDidAppear(false)
            self.loaderView.isHidden = true
        }
    }
    
    /// Set initial editable image
    func setupImage() {
        self.editableImage = self.cropImage
        self.imageView.image = self.editableImage
    }
    
    /// Remove metadata from UIImage to avoid image rotation
    func stripMetadata(from image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let strippedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return strippedImage
    }
    
    /// Setup crop views, buttons, handles, and layers
    private func setupViews() {
        self.editableImage = self.imageView.image
        self.updateImageFrame()
        
        // Layers
        self.mainView.layer.addSublayer(backgroundLayer)
        self.mainView.layer.addSublayer(rectangleLayer)
        
        maskLayer.fillRule = .evenOdd
        
        backgroundLayer.mask = maskLayer
        backgroundLayer.fillColor = UIColor.black.cgColor
        backgroundLayer.opacity = Float(0.7)
        
        rectangleLayer.strokeColor = UIColor.blue.cgColor
        rectangleLayer.fillColor = UIColor.clear.cgColor
        rectangleLayer.lineWidth = 2
        rectangleLayer.lineJoin = .round
        
        // Corner buttons
        [topLeftButton, topRightButton, bottomLeftButton, bottomRightButton].forEach { button in
            button.setImage(UIImage(named:"cropCircleCorner"), for: .normal)
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(buttonPanGestureAction))
            panGestureRecognizer.delegate = self
            button.addGestureRecognizer(panGestureRecognizer)
            
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 64).isActive = true
            button.heightAnchor.constraint(equalToConstant: 64).isActive = true
        }
        
        // Side handles
        leftHandle.setImage(UIImage(named:"cropSideHandleVertical"), for: .normal)
        rightHandle.setImage(UIImage(named:"cropSideHandleVertical"), for: .normal)
        topHandle.setImage(UIImage(named:"cropSideHandleHorizontal"), for: .normal)
        bottomHandle.setImage(UIImage(named:"cropSideHandleHorizontal"), for: .normal)
        
        [topHandle, bottomHandle, leftHandle, rightHandle].forEach { button in
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(sideHandlePanGestureAction(_:)))
            button.addGestureRecognizer(panGestureRecognizer)
            
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            self.mainView.addSubview(button)
        }
        
        // Preview image
        self.previewImageView.isHidden = true
        self.previewImageView.image = self.editableImage
        self.previewImageView.clipsToBounds = true
        self.previewImageView.layer.cornerRadius = 40
        self.previewImageView.layer.borderColor = UIColor.white.cgColor
        self.previewImageView.layer.borderWidth = 2
        
        // Add corner buttons
        self.mainView.addSubview(topLeftButton)
        self.mainView.addSubview(topRightButton)
        self.mainView.addSubview(bottomLeftButton)
        self.mainView.addSubview(bottomRightButton)
        
        self.mainView.bringSubviewToFront(self.previewImageView)
        self.addCrosshairLines()
    }
    
    /// Adds crosshair lines (horizontal and vertical) to the preview image view.
    private func addCrosshairLines() {
        // Remove existing crosshair lines before adding new ones
        self.previewImageView.layer.sublayers?.removeAll(where: { $0.name == "crosshairLine" })
        
        let imageViewBounds = self.previewImageView.bounds
        
        let horizontalLine = CALayer()
        horizontalLine.name = "crosshairLine"
        horizontalLine.backgroundColor = UIColor.white.cgColor
        horizontalLine.frame = CGRect(
            x: 0,
            y: imageViewBounds.height / 2,
            width: imageViewBounds.width,
            height: 1
        )
        
        let verticalLine = CALayer()
        verticalLine.name = "crosshairLine"
        verticalLine.backgroundColor = UIColor.white.cgColor
        verticalLine.frame = CGRect(
            x: imageViewBounds.width / 2,
            y: 0,
            width: 1,
            height: imageViewBounds.height
        )
        self.previewImageView.layer.addSublayer(horizontalLine)
        self.previewImageView.layer.addSublayer(verticalLine)
    }
    
    /// Convert button centers in imageView to image pixel coordinates
    private func convertButtonCentersToImagePoints(imageFrame: CGRect) -> [CGPoint] {
        let topLeftInView = imageView.convert(topLeftButton.center, from: topLeftButton.superview)
        let topRightInView = imageView.convert(topRightButton.center, from: topRightButton.superview)
        let bottomRightInView = imageView.convert(bottomRightButton.center, from: bottomRightButton.superview)
        let bottomLeftInView = imageView.convert(bottomLeftButton.center, from: bottomLeftButton.superview)
        
        let pointsInView = [topLeftInView, topRightInView, bottomRightInView, bottomLeftInView]
        
        return pointsInView.map { point -> CGPoint in
            let normalizedX = (point.x - imageFrame.origin.x) / imageFrame.width
            let normalizedY = (point.y - imageFrame.origin.y) / imageFrame.height
            let pixelX = normalizedX * (imageView.image?.size.width ?? 0)
            let pixelY = normalizedY * (imageView.image?.size.height ?? 0)
            return CGPoint(x: pixelX, y: pixelY)
        }
    }
    
    /// Handles the cropped image: checks size, saves to gallery as PNG, shows alert
    private func handleCroppedImage(_ image: UIImage) {
        let imageData = image.pngData() ?? Data() // Use PNG to preserve transparency
        let croppedImageSizeinKB = imageData.count / 1024
        
        if croppedImageSizeinKB < minimumCroppedImageSize {
            showAlert(message: "The cropped image is too small (less than \(minimumCroppedImageSize)kb). Try selecting a larger area.")
        } else {
            saveImageToGallery(image)
        }
    }
    
    /// Save image to Photos gallery (PNG)
    private func saveImageToGallery(_ image: UIImage) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cropped.png")
        do {
            try image.pngData()?.write(to: tempURL)
        } catch {
            showAlert(message: "Failed to save temporary image: \(error.localizedDescription)")
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showAlert(message: "Cropped image saved in gallery", dismissVC: true)
                } else {
                    self?.showAlert(message: error?.localizedDescription ?? "Failed to save image")
                }
            }
        }
    }

    
    /// Generic alert helper
    private func showAlert(message: String, dismissVC: Bool = false) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            if dismissVC { self.dismiss(animated: true) }
        }))
        present(alert, animated: true)
    }
}

// MARK: - Side Handle & Corner Button Pan Gesture
private extension PolygonCroppingVC {
    
    /// Handles dragging of side handles (top, bottom, left, right).
    @objc private func sideHandlePanGestureAction(_ gesture: UIPanGestureRecognizer) {
        guard let handle = gesture.view, let imageFrame else { return }
        
        let translation = gesture.translation(in: self.mainView)
        
        switch gesture.state {
        case .began:
            // Change handle appearance when dragging starts
            if handle == topHandle{
                topHandle.setImage(UIImage(named:"cropSideHandleHorizontalInvert"), for: .normal)
            }else if handle == bottomHandle {
                bottomHandle.setImage(UIImage(named:"cropSideHandleHorizontalInvert"), for: .normal)
            }else if handle == leftHandle{
                leftHandle.setImage(UIImage(named:"cropSideHandleVerticalInvert"), for: .normal)
            }else if handle == rightHandle {
                rightHandle.setImage(UIImage(named:"cropSideHandleVerticalInvert"), for: .normal)
            }
            
        case .ended:
            // Reset handle appearance when dragging ends
            leftHandle.setImage(UIImage(named:"cropSideHandleVertical"), for: .normal)
            rightHandle.setImage(UIImage(named:"cropSideHandleVertical"), for: .normal)
            topHandle.setImage(UIImage(named:"cropSideHandleHorizontal"), for: .normal)
            bottomHandle.setImage(UIImage(named:"cropSideHandleHorizontal"), for: .normal)
            
        default:
            break
            //print("UIPanGestureRecognizer state \(gesture.state) not handled in ReceiptEditCropImageView")
        }
        
        // Update positions based on handle type
        if handle === topHandle {
            topLeftButton.center.y = min(min(bottomLeftButton.center.y, bottomRightButton.center.y),max(imageFrame.minY, topLeftButton.center.y + translation.y))
            topRightButton.center.y = min(min(bottomLeftButton.center.y, bottomRightButton.center.y),max(imageFrame.minY, topRightButton.center.y + translation.y))
        } else if handle === bottomHandle {
            bottomLeftButton.center.y = max(max(topLeftButton.center.y, topRightButton.center.y),min(imageFrame.maxY, bottomLeftButton.center.y + translation.y))
            bottomRightButton.center.y = max(max(topLeftButton.center.y, topRightButton.center.y),min(imageFrame.maxY, bottomRightButton.center.y + translation.y))
        } else if handle === leftHandle {
            topLeftButton.center.x = min(min(topRightButton.center.x, bottomRightButton.center.x),max(0,max(imageFrame.minX, topLeftButton.center.x + translation.x)))
            bottomLeftButton.center.x = min(min(topRightButton.center.x, bottomRightButton.center.x),max(0,max(imageFrame.minX, bottomLeftButton.center.x + translation.x)))
        } else if handle === rightHandle {
            topRightButton.center.x = max(max(topLeftButton.center.x, bottomLeftButton.center.x),min(imageFrame.maxX, topRightButton.center.x + translation.x))
            bottomRightButton.center.x = max(max(topLeftButton.center.x, bottomLeftButton.center.x),min(imageFrame.maxX, bottomRightButton.center.x + translation.x))
        }
        
        gesture.setTranslation(.zero, in: self.mainView)
        drawRectangle()
        
        self.updateSideHandles()
    }
    
    /// Handles dragging of corner buttons (top-left, top-right, bottom-left, bottom-right).
    @objc private func buttonPanGestureAction(_ gesture: UIPanGestureRecognizer) {
        guard let button = gesture.view as? UIButton else {
            print("buttonPanGestureAction received no view for positioning update")
            return
        }
        
        let animationDuration: CGFloat = 0.1
        switch gesture.state {
            
        case .began:
            if activeButton != nil && activeButton !== button {
                gesture.state = .ended
                activeButton = nil
                activeButtonGesture?.state = .ended
                return
            }
            activeButton = button
            activeButtonGesture = gesture
            
            UIView.animate(withDuration: animationDuration) {
                button.setImage(UIImage(named:"cropCircleCornerInvert"), for: .normal)
                self.previewImageView.isHidden = false
                button.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            }
            
        case .ended, .cancelled, .failed:
            [topLeftButton, topRightButton, bottomLeftButton, bottomRightButton].forEach { btn in
                btn.setImage(UIImage(named:"cropCircleCorner"), for: .normal)
                btn.transform = .identity
            }
            previewImageView.isHidden = true
            activeButton = nil
            activeButtonGesture = nil
            
        default:
            if activeButton !== button { return }
            // Unhandled states
        }
        
        guard let imageFrame else {
            //print("Could not unwrap current image frame")
            return
        }
        
        // --- Safe area constraints
        let minXSafeArea: CGFloat = imageFrame.origin.x + 1
        let maxXSafeArea: CGFloat = imageFrame.origin.x + imageFrame.width - 1
        let minYSafeArea: CGFloat = imageFrame.origin.y + 1
        let maxYSafeArea: CGFloat = imageFrame.height + minYSafeArea - 1
        
        let topLeftButtonMaxX = topRightButton.center.x
        let bottomLeftButtonMaxX = bottomRightButton.center.x
        let leftButtonsMaxX = min(topLeftButtonMaxX, bottomLeftButtonMaxX)
        
        let topRightButtonMinX = topLeftButton.center.x
        let bottomRightButtonMinX = bottomLeftButton.center.x
        let rightButtonsMinX = max(topRightButtonMinX, bottomRightButtonMinX)
        
        let topRightButtonMaxY = bottomRightButton.center.y
        let topLeftButtonMaxY = bottomLeftButton.center.y
        let topButtonsMaxY = min(topRightButtonMaxY, topLeftButtonMaxY)
        
        let bottomRightButtonMinY = topRightButton.center.y
        let bottomLeftButtonMinY = topLeftButton.center.y
        let bottomButtonsMinY = max(bottomRightButtonMinY, bottomLeftButtonMinY)
        
        let point = gesture.translation(in: self.mainView)
        
        // --- Apply translation
        let xPosition: CGFloat
        let yPosition: CGFloat
        if button === topLeftButton {
            xPosition = max(minXSafeArea, min(button.center.x + point.x, leftButtonsMaxX))
            yPosition = max(minYSafeArea, min(button.center.y + point.y, topButtonsMaxY))
        } else if button === topRightButton {
            xPosition = min(maxXSafeArea, max(button.center.x + point.x, rightButtonsMinX))
            yPosition = max(minYSafeArea, min(button.center.y + point.y, topButtonsMaxY))
        } else if button === bottomLeftButton {
            xPosition = max(minXSafeArea, min(button.center.x + point.x, leftButtonsMaxX))
            yPosition = min(maxYSafeArea, max(button.center.y + point.y, bottomButtonsMinY))
        } else if button === bottomRightButton {
            xPosition = min(maxXSafeArea, max(button.center.x + point.x, rightButtonsMinX))
            yPosition = min(maxYSafeArea, max(button.center.y + point.y, bottomButtonsMinY))
        } else { return }
        
        // Update button + preview
        self.setMagnifierPosition(xPos: xPosition, yPos: yPosition)
        button.center = CGPoint(x: xPosition, y: yPosition)
        
        //print("button location:", button.center)
        if let image = self.imageView.image {
            if let mainImage = self.stripMetadata(from: image) {
                let zoomedImage = getZoomedImage(from: mainImage, at: CGPoint(x: xPosition, y: yPosition), zoomScale: 1, size: self.previewImageView.bounds.size)
                self.previewImageView.image = zoomedImage
            }
        }
        
        gesture.setTranslation(CGPoint.zero, in: self.mainView)
        
        updateSideHandles()
        drawRectangle()
    }
    
    /// Shows/hides side handles depending on the active corner.
    private func handleView(currentSelected: UIButton) {
        [topHandle, bottomHandle, leftHandle, rightHandle].forEach { button in
            button.isHidden = true
        }
        
        if currentSelected == self.topLeftButton {
            self.rightHandle.isHidden = false
            self.bottomHandle.isHidden = false
        }else if currentSelected == self.topRightButton {
            self.leftHandle.isHidden = false
            self.bottomHandle.isHidden = false
        }else if currentSelected == self.bottomLeftButton {
            self.rightHandle.isHidden = false
            self.topHandle.isHidden = false
        }else if currentSelected == self.bottomRightButton {
            self.leftHandle.isHidden = false
            self.topHandle.isHidden = false
        }else {
            return
        }
    }
    
    /// Updates the positions and rotations of side handles based on current corner button positions.
    private func updateSideHandles() {
        // --- Top handle
        let topHandlex = topLeftButton.center.x + abs((topRightButton.center.x - topLeftButton.center.x) / 2)
        let topHandley = min(topLeftButton.center.y , topRightButton.center.y) + abs((topLeftButton.center.y - topRightButton.center.y) / 2)
        
        let topHandle_dx = topRightButton.center.x - topLeftButton.center.x
        let topHandle_dy = topRightButton.center.y - topLeftButton.center.y
        let topHandle_angle = atan2(topHandle_dy, topHandle_dx)
        
        topHandle.transform = CGAffineTransform(rotationAngle: topHandle_angle)
        
        topHandle.center = CGPoint (
            x: topHandlex,
            y: topHandley
        )
        
        // --- Bottom handle
        let bottomHandlex = bottomLeftButton.center.x + abs((bottomRightButton.center.x - bottomLeftButton.center.x) / 2)
        let bottomHandley = min(bottomLeftButton.center.y , bottomRightButton.center.y) + abs((bottomLeftButton.center.y - bottomRightButton.center.y) / 2)
        
        let bottomHandle_dx = bottomRightButton.center.x - bottomLeftButton.center.x
        let bottomHandle_dy = bottomRightButton.center.y - bottomLeftButton.center.y
        let bottomHandle_angle = atan2(bottomHandle_dy, bottomHandle_dx)
        
        bottomHandle.transform = CGAffineTransform(rotationAngle: bottomHandle_angle)
        
        bottomHandle.center = CGPoint(
            x: bottomHandlex,
            y: bottomHandley
        )
        
        // --- Left handle
        let leftHandlex = min(bottomLeftButton.center.x, topLeftButton.center.x) + abs((bottomLeftButton.center.x - topLeftButton.center.x) / 2)
        let leftHandley = topLeftButton.center.y + abs((bottomLeftButton.center.y - topLeftButton.center.y) / 2)
        
        let leftHandle_dx = bottomLeftButton.center.x - topLeftButton.center.x
        let leftHandle_dy = bottomLeftButton.center.y - topLeftButton.center.y
        let leftHandle_angle = atan2(leftHandle_dy, leftHandle_dx) - .pi / 2
        
        leftHandle.transform = CGAffineTransform(rotationAngle: leftHandle_angle)
        
        leftHandle.center = CGPoint(
            x: leftHandlex,
            y: leftHandley
        )
        
        // --- Right handle
        let rightHandlex = min(bottomRightButton.center.x, topRightButton.center.x) + abs((bottomRightButton.center.x - topRightButton.center.x) / 2)
        let rightHandley = topRightButton.center.y + abs((bottomRightButton.center.y - topRightButton.center.y) / 2)
        
        let rightHandle_dx = bottomRightButton.center.x - topRightButton.center.x
        let rightHandle_dy = bottomRightButton.center.y - topRightButton.center.y
        let rightHandle_angle = atan2(rightHandle_dy, rightHandle_dx) - .pi / 2
        
        rightHandle.transform = CGAffineTransform(rotationAngle: rightHandle_angle)
        
        rightHandle.center = CGPoint(
            x: rightHandlex,
            y: rightHandley
        )
        
        [topHandle, bottomHandle, leftHandle, rightHandle].forEach { button in
            button.isHidden = false
        }
    }
}

// MARK: - Image Cropping & Masking
extension PolygonCroppingVC {
    
    /// Crop image inside quadrilateral
    func cropImage(
        image: UIImage,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint,
        completion: @escaping (UIImage?) -> Void
    ) {
        let alert = UIAlertController(
            title: "Choose Option",
            message: "Select how you want to process the image",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Crop", style: .default, handler: { _ in
            let cropped = self.cropImageInQuadrilateral(
                image: image,
                topLeft: topLeft,
                topRight: topRight,
                bottomRight: bottomRight,
                bottomLeft: bottomLeft
            )
            completion(cropped)
        }))
        
        alert.addAction(UIAlertAction(title: "Draw Black Background", style: .default, handler: { _ in
            let masked = self.maskImageInQuadrilateral(
                image: image,
                topLeft: topLeft,
                topRight: topRight,
                bottomRight: bottomRight,
                bottomLeft: bottomLeft
            )
            completion(masked)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            completion(nil)
        }))
        
        present(alert, animated: true)
    }
    
    /// Mask image with black background inside quadrilateral
    func maskImageInQuadrilateral(
        image: UIImage,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint
    ) -> UIImage? {
        let size = image.size
        let scale = image.scale
        
        UIGraphicsBeginImageContextWithOptions(size, true, scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.beginPath()
        context.move(to: topLeft)
        context.addLine(to: topRight)
        context.addLine(to: bottomRight)
        context.addLine(to: bottomLeft)
        context.closePath()
        context.clip()
        image.draw(at: .zero)
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resultImage
    }
    
    /// Crop image inside quadrilateral (transparent outside)
    func cropImageInQuadrilateral(
        image: UIImage,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint
    ) -> UIImage? {
        let size = image.size
        let scale = image.scale
        
        // Transparent context
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Clear background
        context.clear(CGRect(origin: .zero, size: size))
        
        // Clip to quadrilateral
        context.beginPath()
        context.move(to: topLeft)
        context.addLine(to: topRight)
        context.addLine(to: bottomRight)
        context.addLine(to: bottomLeft)
        context.closePath()
        context.clip()
        
        image.draw(at: .zero)
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    
}

// MARK: - Crop Rectangle Setup & Drawing
extension PolygonCroppingVC {
    
    /// Setup default crop rectangle and handles
    private func setupDefaultCropRectangle() {
        updateImageFrame()
        
        guard let imageFrame else {
            print("Could not unwrap otiginal image bounds")
            return
        }
        
        let inset = 0.0
        let topLeft = CGPoint(
            x: imageFrame.minX + inset,
            y: imageFrame.minY + inset
        )
        let topRight = CGPoint(
            x: imageFrame.maxX - inset,
            y: imageFrame.minY + inset
        )
        let bottomLeft = CGPoint(
            x: imageFrame.minX + inset,
            y: imageFrame.maxY - inset
        )
        let bottomRight = CGPoint(
            x: imageFrame.maxX - inset,
            y: imageFrame.maxY - inset
        )
        
        // Position side handles
        topHandle.center = CGPoint(
            x: (topLeft.x + topRight.x) / 2,
            y: topLeft.y
        )
        bottomHandle.center = CGPoint(
            x: (bottomLeft.x + bottomRight.x) / 2,
            y: bottomLeft.y
        )
        leftHandle.center = CGPoint(
            x: topLeft.x,
            y: (topLeft.y + bottomLeft.y) / 2
        )
        rightHandle.center = CGPoint(
            x: topRight.x,
            y: (topRight.y + bottomRight.y) / 2
        )
        
        // Position corner buttons
        topLeftButton.center = topLeft
        topRightButton.center = topRight
        bottomLeftButton.center = bottomLeft
        bottomRightButton.center = bottomRight
        
        drawRectangle()
        updateSideHandles()
    }
    
    /// Draw the crop rectangle and mask layers
    private func drawRectangle() {
        guard let imageFrame else {
            print("Could not unwrap current image frame")
            return
        }
        
        // Crop rectangle
        let rectangle = UIBezierPath.init()
        rectangle.move(to: topLeftButton.center)
        rectangle.addLine(to: topLeftButton.center)
        rectangle.addLine(to: topRightButton.center)
        rectangle.addLine(to: bottomRightButton.center)
        rectangle.addLine(to: bottomLeftButton.center)
        rectangle.addLine(to: topLeftButton.center)
        rectangle.close()
        rectangleLayer.path = rectangle.cgPath
        
        // Mask path
        let mask = UIBezierPath.init(rect: imageFrame)
        mask.move(to: topLeftButton.center)
        mask.addLine(to: topLeftButton.center)
        mask.addLine(to: topRightButton.center)
        mask.addLine(to: bottomRightButton.center)
        mask.addLine(to: bottomLeftButton.center)
        mask.addLine(to: topLeftButton.center)
        mask.close()
        maskLayer.path = mask.cgPath
        
        // Background layer
        let path = UIBezierPath(rect: imageFrame)
        backgroundLayer.path = path.cgPath
    }
}

// MARK: - Image Frame & Zoomed Preview
extension PolygonCroppingVC {
    
    /// Update image frame according to imageView and image aspect ratio
    private func updateImageFrame() {
        guard let image = self.imageView.image else { return }
        
        let imageViewSize = imageView.bounds.size
        let imageSize = image.size
        
        let imageViewAspect = imageViewSize.width / imageViewSize.height
        let imageAspect = imageSize.width / imageSize.height
        
        var scaleFactor: CGFloat
        var scaledImageSize: CGSize
        var imageX: CGFloat = 0
        var imageY: CGFloat = 0
        
        if imageAspect > imageViewAspect {
            scaleFactor = imageViewSize.width / imageSize.width
            scaledImageSize = CGSize(width: imageViewSize.width, height: imageSize.height * scaleFactor)
            imageY = (imageViewSize.height - scaledImageSize.height) / 2
        } else {
            scaleFactor = imageViewSize.height / imageSize.height
            scaledImageSize = CGSize(width: imageSize.width * scaleFactor, height: imageViewSize.height)
            imageX = (imageViewSize.width - scaledImageSize.width) / 2
        }
        
        self.imageFrame = CGRect(x: imageX, y: imageY, width: scaledImageSize.width, height: scaledImageSize.height)
    }
    
    /// Get zoomed image for preview magnifier
    private func getZoomedImage(from image: UIImage, at centrepoint: CGPoint, zoomScale: CGFloat, size: CGSize) -> UIImage? {
        let previewImagePosition = imageView.convert(centrepoint, from: self.mainView)
        
        guard let imageFrame = imageFrame else { return nil }
        
        let normalizedX = (previewImagePosition.x - imageFrame.origin.x) / imageFrame.width
        let normalizedY = (previewImagePosition.y - imageFrame.origin.y) / imageFrame.height
        
        let pixelX = normalizedX * image.size.width
        let pixelY = normalizedY * image.size.height
        let pointsInImage =  CGPoint(x: pixelX, y: pixelY)
        
        let scale = image.scale
        let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        let cropSize = CGSize(width: size.width / zoomScale, height: size.height / zoomScale)
        let cropOrigin = CGPoint(
            x: max(min(pointsInImage.x * scale - cropSize.width / 2, imageSize.width - cropSize.width), 0),
            y: max(min(pointsInImage.y * scale - cropSize.height / 2, imageSize.height - cropSize.height), 0)
        )
        
        let cropRect = CGRect(origin: cropOrigin, size: cropSize).integral
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        croppedImage.draw(in: CGRect(origin: .zero, size: size))
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage
    }
    
    /// Position the magnifier preview
    func setMagnifierPosition(xPos: CGFloat, yPos: CGFloat) {
        guard let imageFrame = self.imageFrame else { return }
        
        self.previewImageView.center = CGPoint(x: xPos, y: yPos - 100)
        
        //You can manage safe area from here
        /*
        let maxXSafeArea: CGFloat = imageFrame.origin.x + imageFrame.width - 1
        let minYSafeArea: CGFloat = imageFrame.origin.y + 1
        
        let difference = (self.mainView.frame.height - imageFrame.height)/2
        
        if yPos - 120 < minYSafeArea - difference - 10{
            self.previewImageView.center = CGPoint(x: max(30, min(xPos, maxXSafeArea - 30)), y: yPos + 100)
        }else {
            self.previewImageView.center = CGPoint(x: max(30, min(xPos, maxXSafeArea - 30)), y: yPos - 100)
        }
        */
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension PolygonCroppingVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
