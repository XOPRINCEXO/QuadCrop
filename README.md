# Quad Crop

**QuadCrop** is an iOS application that allows users to crop images in a flexible, freeform quadrilateral shape. Unlike standard rectangular cropping, QuadCrop provides draggable corner handles so that users can select any four-sided region of an image and either crop it or apply a black background mask.

## Key Features
- **Interactive Quadrilateral Selection:** Drag corner handles to define any four-sided cropping area.
- **Flexible Cropping Options:** Crop images inside the selected quadrilateral or fill the outside area with a black background.
- **High-Quality Output:** Cropped images are saved to the Photos gallery with minimal quality loss.
- **Safe Cropping Feedback:** Prevents saving very small cropped images with a size warning.
- **Dynamic Preview:** Zoomed preview magnifier shows the selected region clearly while adjusting handles.

## Use Cases
- Cropping photos for creative layouts or documents.
- Preparing images for presentations or design assets.
- Removing unwanted areas or backgrounds efficiently with precision.

## Technologies
- Swift & UIKit for UI and interactions.
- Core Graphics for image processing.
- Photos framework for saving images to the gallery.

## Demo Video
![QuadCrop Demo](assets/quadcrop-demo.gif)
