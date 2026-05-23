cmake_minimum_required(VERSION 3.16)

project(vpt01 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(appvpt01
    main.cpp
)

qt_add_qml_module(appvpt01
    URI vpt01
    QML_FILES
        Main.qml
        SOURCES backend.h backend.cpp
        QML_FILES
        QML_FILES StyledPopup.qml
        QML_FILES StyledButton.qml
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

install(TARGETS appvpt01
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
