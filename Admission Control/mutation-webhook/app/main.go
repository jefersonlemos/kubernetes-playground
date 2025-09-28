package main

import (
	// "context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	// "os"

	"k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	tlsCertFile = "/etc/webhook/certs/cert.pem"
	tlsKeyFile  = "/etc/webhook/certs/key.pem"
)

// The `main` function starts the webhook server
func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/mutate", handleMutate)

	server := &http.Server{
		Addr:    ":8443",
		Handler: mux,
	}

	log.Println("Starting webhook server on :8443...")
	if err := server.ListenAndServeTLS(tlsCertFile, tlsKeyFile); err != nil && err != http.ErrServerClosed {
		log.Fatalf("could not start webhook server: %v", err)
	}
}

// `handleMutate` processes AdmissionReview requests for pod mutations
func handleMutate(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, fmt.Sprintf("could not read request body: %v", err), http.StatusBadRequest)
		return
	}

	admissionReview := v1.AdmissionReview{}
	if err := json.Unmarshal(body, &admissionReview); err != nil {
		http.Error(w, fmt.Sprintf("could not unmarshal request: %v", err), http.StatusBadRequest)
		return
	}

	admissionResponse := &v1.AdmissionResponse{
		UID:     admissionReview.Request.UID,
		Allowed: true,
	}

	if admissionReview.Request.Resource.Resource == "pods" {
		raw := admissionReview.Request.Object.Raw
		pod := corev1.Pod{}
		if err := json.Unmarshal(raw, &pod); err != nil {
			http.Error(w, fmt.Sprintf("could not unmarshal pod: %v", err), http.StatusBadRequest)
			return
		}
		
		// Create a JSON patch to inject the environment variable
		patch := createPatch(&pod)
		if patch != nil {
			pt := v1.PatchTypeJSONPatch
			admissionResponse.Patch = patch
			admissionResponse.PatchType = &pt
		}
	}

	responseAdmissionReview := v1.AdmissionReview{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "admission.k8s.io/v1",
			Kind:       "AdmissionReview",
		},
		Response: admissionResponse,
	}

	resp, err := json.Marshal(responseAdmissionReview)
	if err != nil {
		http.Error(w, fmt.Sprintf("could not marshal response: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if _, err := w.Write(resp); err != nil {
		log.Printf("could not write response: %v", err)
	}
}

// `createPatch` generates the JSON patch for a given pod
func createPatch(pod *corev1.Pod) []byte {
	// Only patch if the first container exists
	if len(pod.Spec.Containers) == 0 {
		return nil
	}
	
	// Create the environment variable object
	envVar := corev1.EnvVar{
		Name:  "INJECTED_ENV",
		Value: "true",
	}

	// Create the JSON patch operation
	patch := []map[string]interface{}{
		{
			"op":   "add",
			"path": "/spec/containers/0/env/-",
			"value": envVar,
		},
	}
	
	patchBytes, err := json.Marshal(patch)
	if err != nil {
		log.Printf("could not marshal patch: %v", err)
		return nil
	}
	
	return patchBytes
}

