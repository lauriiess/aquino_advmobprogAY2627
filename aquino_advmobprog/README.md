# Jhane Laurice V. Aquino
## INF233
## CTADMOBL Advanced Mobile Programming

A Flutter project that focuses on advance topics. Covering the web to mobile transactions

## Lab Activity Instance

## Laboratory List
**Lab 1 - Theme (Dark/Light Mode)** The setState is used for simple changes inside one widget, like the counter in this activity. It updates only that widget. Provider is used when data needs to be shared across different widgets, like the app theme. setState is good for small tasks, while Provider is better for managing shared data in bigger apps.

**Lab 2 - Utilizing 3rd Party API**: The model, service, and screen work together to retrieve and display data from the API endpoint. The model represents the product data, the service handles the API request and converts the response into Product objects, and the screen uses FutureBuilder to display the products in the UI. This activity also introduces the Service Layer pattern, which separates API and data-fetching logic from the user interface, making the code more organized, reusable, and easier to maintain.  

**Lab 3 - Cart API Integration** In this activity, the Cart Model, Cart Service, and Cart Screen work together to display cart data from the API. The Cart Model handles the cart data structure, the Cart Service connects to the API and retrieves the cart, and the Cart Screen displays the products. Clicking a product opens the same detail_screen.dart used for product details. The updated design separates the model, service, and screen responsibilities, making the code more organized. The getCartByUserId() method uses the /carts/user/{id} endpoint to retrieve the cart of a specific user instead of loading all carts, while the add-to-cart endpoint allows products to be added to the user's cart.

**Lab 4 - User Management** This activity added a User model so login data from the API has a proper shape instead of a loose map, and user_service.dart saves that data to SharedPreferences so the session can persist across app restarts. The splash_screen checks for this saved session on launch and skips straight to home if the user is already logged in, otherwise it goes to signin_screen, which logs in and saves the data the same way. The profile_screen then just asks user_service for the saved user and displays it. That same saved user ID is also passed into cart_screen, so it only loads and shows that specific user's cart instead of a random one.

**Lab 5 – Firebase Authentication** For this laboratory activity, we integrated Firebase Authentication alongside our existing DummyJSON setup to simulate a flexible, real-world sign-in and registration workflow. By routing all backend tasks, such as credential verification, account creation, and profile updates, through a centralized UserService class, we successfully decoupled our UI screens from messy authentication logic. This design acts as a single source of truth for the app: whenever a user signs in, their session type is securely cached locally, allowing interface components like the profile screen to dynamically adapt their available actions and displayed fields without redundant code. Ultimately, this approach keeps the codebase clean and maintainable while ensuring that complex security tasks, like session persistence and user state management, operate smoothly behind the scenes.