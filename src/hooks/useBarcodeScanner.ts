import {
  runAtTargetFps,
  useFrameProcessor,
  type Camera,
  type CameraProps,
  type Frame,
} from "@jmstechnologiesinc/react-native-vision-camera";
import { useEffect, useRef, useState } from "react";
import { Platform, type ViewProps } from "react-native";
import { Worklets, useSharedValue } from "react-native-worklets-core";
import { scanCodes, type ScanBarcodesOptions } from "src/module";
import type { Barcode, BarcodeType, Highlight, Rect, Size } from "src/types";
import { computeHighlights } from "src/utils";

export type UseBarcodeScannerOptions = {
  barcodeTypes?: BarcodeType[];
  regionOfInterest?: Rect;
  fps?: number;
  onBarcodeScanned: (barcodes: Barcode[], frame: Frame) => void;
  disableHighlighting?: boolean;
  defaultResizeMode?: CameraProps["resizeMode"];
  scanMode?: "continuous" | "once";
};

export const useBarcodeScanner = ({
  barcodeTypes,
  regionOfInterest,
  onBarcodeScanned,
  disableHighlighting,
  defaultResizeMode = "cover",
  scanMode = "continuous",
  fps = 2,
}: UseBarcodeScannerOptions) => {
  const ref = useRef<Camera>(null);

  // Layout of the <Camera /> component
  const layoutRef = useSharedValue<Size>({ width: 0, height: 0 });
  const onLayout: ViewProps["onLayout"] = (event) => {
    const { width, height } = event.nativeEvent.layout;
    layoutRef.value = { width, height };
  };

  // Track resizeMode changes and pass it to the worklet
  const resizeModeRef =
    useSharedValue<CameraProps["resizeMode"]>(defaultResizeMode);
  useEffect(() => {
    resizeModeRef.value = ref.current?.props.resizeMode || defaultResizeMode;
  }, [resizeModeRef, ref.current?.props.resizeMode, defaultResizeMode]);

  //
  const isPristineRef = useSharedValue<boolean>(true);

  // Barcode highlights related state
  const barcodesRef = useSharedValue<Barcode[]>([]);

  // Barcode highlights related state
  const [highlights, setHighlights] = useState<Highlight[]>([]);
  const lastHighlightsCount = useSharedValue<number>(0);
  const setHighlightsJS = Worklets.createRunInJsFn(setHighlights);

  // Pixel format must be "yuv" on Android and "native" on iOS
  const pixelFormat: CameraProps["pixelFormat"] =
    Platform.OS === "android" ? "yuv" : "native";

  const frameProcessor = useFrameProcessor(
    (frame) => {
      "worklet";
      runAtTargetFps(fps, () => {
        "worklet";
        const { value: layout } = layoutRef;
        const { value: prevBarcodes } = barcodesRef;
        const { value: resizeMode } = resizeModeRef;
        // Call the native barcode scanner
        const options: ScanBarcodesOptions = {};
        if (barcodeTypes !== undefined) {
          options.barcodeTypes = barcodeTypes;
        }
        if (regionOfInterest !== undefined) {
          const { x, y, width, height } = regionOfInterest;
          options.regionOfInterest = [x, y, width, height];
        }
        const barcodes = scanCodes(frame, options);

        if (barcodes.length > 0) {
          // If the scanMode is "continuous", we stream all the barcodes responses
          if (scanMode === "continuous") {
            onBarcodeScanned(barcodes, frame);
            // If the scanMode is "once", we only call the callback if the barcodes have actually changed
          } else if (scanMode === "once") {
            const hasChanged =
              prevBarcodes.length !== barcodes.length ||
              JSON.stringify(prevBarcodes.map(({ value }) => value)) !==
                JSON.stringify(barcodes.map(({ value }) => value));
            if (hasChanged) {
              onBarcodeScanned(barcodes, frame);
            }
          }
          barcodesRef.value = barcodes;
        }

        if (disableHighlighting !== true && resizeMode !== undefined) {
          // We must ignore the first frame because as it has width/height inverted (maybe the right value though?)
          if (isPristineRef.value) {
            isPristineRef.value = false;
            return;
          }
          const highlights = computeHighlights(
            barcodes,
            frame,
            layout,
            resizeMode,
          );
          // Spare a re-render if the highlights are both empty
          if (lastHighlightsCount.value === 0 && highlights.length === 0) {
            return;
          }
          lastHighlightsCount.value = highlights.length;
          setHighlightsJS(highlights);
        }
      });
    },
    [layoutRef, resizeModeRef, disableHighlighting],
  );

  return {
    props: {
      pixelFormat,
      frameProcessor,
      onLayout,
      ref,
      resizeMode: defaultResizeMode,
    },
    highlights,
    ref,
  };
};
