# Jhane Laurice V. Aquino
## INF233
## CTADMOBL Advanced Mobile Programming

A Flutter project that focuses on advance topics. Covering the web to mobile transactions

## Lab Activity Instance

## Laboratory List
**Lab 1 - Theme (Dark/Light Mode)** The setState is used for simple changes inside one widget, like the counter in this activity. It updates only that widget. Provider is used when data needs to be shared across different widgets, like the app theme. setState is good for small tasks, while Provider is better for managing shared data in bigger apps.

**Lab 2 - Utilizing 3rd Party API**: The model, service, and screen work together to retrieve and display data from the API endpoint. The model represents the product data, the service handles the API request and converts the response into Product objects, and the screen uses FutureBuilder to display the products in the UI. This activity also introduces the Service Layer pattern, which separates API and data-fetching logic from the user interface, making the code more organized, reusable, and easier to maintain.  

**Lab 3 - Cart API Integration** In this activity, the Cart Model, Cart Service, and Cart Screen work together to display cart data from the API. The Cart Model handles the cart data structure, the Cart Service connects to the API and retrieves the cart, and the Cart Screen displays the products. Clicking a product opens the same detail_screen.dart used for product details. The updated design separates the model, service, and screen responsibilities, making the code more organized. The getCartByUserId() method uses the /carts/user/{id} endpoint to retrieve the cart of a specific user instead of loading all carts, while the add-to-cart endpoint allows products to be added to the user's cart.
