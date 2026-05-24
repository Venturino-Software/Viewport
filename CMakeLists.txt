cmake_minimum_required(VERSION 3.16)

project(vpt01 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Core5Compat) # <-- Agrega Core5Compat aquí\\\

qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(appvpt01
    main.cpp
)

qt_add_qml_module(appvpt01
    URI vpt01
    VERSION 1.0
    SOURCES backend.h backend.cpp
    SOURCES iconprovider.h
    QML_FILES FontManager.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appvpt01 PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appvpt01
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appvpt01
    PRIVATE Qt6::Quick
)

file(COPY Main.qml StyledPopup.qml StyledButton.qml FirstStart.qml
    DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
)
# 1. Instalar el ejecutable directamente en 'bin'
install(TARGETS appvpt01
    RUNTIME DESTINATION bin
)

# 2. Instalar los archivos QML en el mismo lugar
install(FILES
    Main.qml
    StyledPopup.qml
    StyledButton.qml
    FirstStart.qml
    DESTINATION bin
)
